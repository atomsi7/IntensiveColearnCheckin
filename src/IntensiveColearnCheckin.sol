// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title IntensiveColearnCheckin
 * @dev A smart contract for managing intensive co-learning checkins with peer review system
 */
contract IntensiveColearnCheckin is Ownable {

    // Structs
    struct Checkin {
        uint256 id;
        address user;
        string note;
        uint256 timestamp;
        uint256 likes;
        uint256 mehs;
        bool isLikedByOrganizer;
        bool isValid;
    }

    struct User {
        address userAddress;
        uint256 totalCheckins;
        uint256 lastCheckinWeek;
        bool isBlocked;
        uint256 notCheckinTimesInaWeek; // Track missed check-ins in current week
        bool checkInToday; // Track if user checked in today
        mapping(uint256 => bool) weeklyCheckins; // week number => has checked in
    }

    // State variables
    uint256 private _checkinIds;
    mapping(address => User) public users;
    mapping(uint256 => Checkin) public checkins;
    mapping(address => mapping(uint256 => uint256)) public userCheckins; // user => week => checkinId
    
    // User interaction tracking for like/meh functionality
    mapping(address => mapping(uint256 => bool)) public userLikedCheckin; // user => checkinId => has liked
    mapping(address => mapping(uint256 => bool)) public userMehedCheckin; // user => checkinId => has mehed
    
    // Automatic checking variables
    uint256 public lastAutoCheckTime;
    uint256 public constant AUTO_CHECK_INTERVAL = 24 hours;
    address[] public registeredUsers;
    mapping(address => bool) public isRegisteredUser;
    
    // Time manipulation variable
    uint256 public skipedTime;
    
    // Deployment timestamp for relative time calculations
    uint256 public deploymentTimestamp;
    
    // Events
    event CheckinCreated(uint256 indexed checkinId, address indexed user, string note, uint256 timestamp);
    event CheckinLiked(uint256 indexed checkinId, address indexed liker);
    event CheckinMehed(uint256 indexed checkinId, address indexed meher);
    event CheckinUnliked(uint256 indexed checkinId, address indexed unliker);
    event CheckinUnmehed(uint256 indexed checkinId, address indexed unmeher);
    event UserBlocked(address indexed user, uint256 week);
    event UserUnblocked(address indexed user);
    event AutoCheckPerformed(uint256 timestamp, uint256 usersChecked, uint256 usersBlocked);
    event TimeSkipped(uint256 skippedSeconds, uint256 newRealTime);

    // Constants
    uint256 public constant DAYS_IN_WEEK = 7;
    uint256 public constant MEH_THRESHOLD_PERCENTAGE = 67; // 67% meh threshold
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant ALLOWED_MISSING_CHECKINS_PER_WEEK = 2;

    constructor() Ownable(msg.sender) {
        lastAutoCheckTime = getRealTime();
        deploymentTimestamp = block.timestamp;
    }

    /**
     * @dev Skip one day (24 hours) - only owner can call
     */
    function skipOneDay() external onlyOwner {
        skipedTime += 24 hours;
        // Reset checkInToday flag for all users when time is skipped
        for (uint256 i = 0; i < registeredUsers.length; i++) {
            address user = registeredUsers[i];
            users[user].checkInToday = false;
        }
        emit TimeSkipped(24 hours, getRealTime());
    }

    /**
     * @dev Get the real time (block.timestamp + skipedTime)
     * @return The real time
     */
    function getRealTime() public view returns (uint256) {
        return block.timestamp + skipedTime;
    }

    /**
     * @dev Create a new checkin for the current day
     * @param note The checkin note
     */
    function checkin(string memory note) external {
        require(!users[msg.sender].isBlocked, "User is blocked");
        require(bytes(note).length > 0, "Note cannot be empty");
        
        uint256 currentWeek = getCurrentWeek();
        uint256 currentDay = getCurrentDay();
        
        // Check if user already checked in today
        require(userCheckins[msg.sender][currentDay] == 0, "Already checked in today");
        
        // Register user if not already registered
        if (!isRegisteredUser[msg.sender]) {
            registeredUsers.push(msg.sender);
            isRegisteredUser[msg.sender] = true;
        }
        
        // Create new checkin
        _checkinIds++;
        uint256 checkinId = _checkinIds;
        
        checkins[checkinId] = Checkin({
            id: checkinId,
            user: msg.sender,
            note: note,
            timestamp: getRealTime(),
            likes: 0,
            mehs: 0,
            isLikedByOrganizer: false,
            isValid: true
        });
        
        // Update user data
        User storage user = users[msg.sender];
        user.userAddress = msg.sender;
        user.totalCheckins++;
        
        user.lastCheckinWeek = currentWeek;
        user.weeklyCheckins[currentWeek] = true;
        user.checkInToday = true; // Set checkInToday to true
        userCheckins[msg.sender][currentDay] = checkinId;
        
        emit CheckinCreated(checkinId, msg.sender, note, getRealTime());
    }

    /**
     * @dev Like a checkin (only non-owners can like)
     * @param checkinId The ID of the checkin to like
     */
    function likeCheckin(uint256 checkinId) external {
        require(checkinId > 0 && checkinId <= _checkinIds, "Invalid checkin ID");
        require(!userLikedCheckin[msg.sender][checkinId], "Already liked this checkin");
        require(!userMehedCheckin[msg.sender][checkinId], "Cannot like a checkin you have mehed");
        
        Checkin storage checkinData = checkins[checkinId];
        checkinData.likes++;
        userLikedCheckin[msg.sender][checkinId] = true;

        if (msg.sender == owner()) {
            checkinData.isLikedByOrganizer = true;
            if (checkinData.isValid == false) {
                checkinData.isValid = true;
            }
        }
        
        emit CheckinLiked(checkinId, msg.sender);
    }

    /**
     * @dev Meh a checkin (only non-owners can meh)
     * @param checkinId The ID of the checkin to meh
     */
    function mehCheckin(uint256 checkinId) external {
        require(checkinId > 0 && checkinId <= _checkinIds, "Invalid checkin ID");
        require(msg.sender != owner(), "Organizer cannot meh checkins");
        require(!userMehedCheckin[msg.sender][checkinId], "Already mehed this checkin");
        require(!userLikedCheckin[msg.sender][checkinId], "Cannot meh a checkin you have liked");
        
        Checkin storage checkinData = checkins[checkinId];
        checkinData.mehs++;
        userMehedCheckin[msg.sender][checkinId] = true;
        
        // Check if meh threshold is reached
        if (!checkinData.isLikedByOrganizer) {
            uint256 totalVotes = checkinData.likes + checkinData.mehs;
            if (totalVotes > 0) {
                uint256 mehPercentage = (checkinData.mehs * 100) / registeredUsers.length;
                if (mehPercentage >= MEH_THRESHOLD_PERCENTAGE) {
                    checkinData.isValid = false;
                }
            }
        }
        
        emit CheckinMehed(checkinId, msg.sender);
    }

    /**
     * @dev Unlike a checkin (only non-owners can unlike)
     * @param checkinId The ID of the checkin to unlike
     */
    function unlikeCheckin(uint256 checkinId) external {
        require(checkinId > 0 && checkinId <= _checkinIds, "Invalid checkin ID");
        require(userLikedCheckin[msg.sender][checkinId], "Have not liked this checkin");
        
        Checkin storage checkinData = checkins[checkinId];
        checkinData.likes--;
        userLikedCheckin[msg.sender][checkinId] = false;

        if (msg.sender == owner()) {
            checkinData.isLikedByOrganizer = false;
            // Recalculate meh threshold since organizer unlike removed protection
            uint256 totalVotes = checkinData.likes + checkinData.mehs;
            if (totalVotes > 0) {
                uint256 mehPercentage = (checkinData.mehs * 100) / registeredUsers.length;
                if (mehPercentage >= MEH_THRESHOLD_PERCENTAGE) {
                    checkinData.isValid = false;
                }
            }
        }
        
        emit CheckinUnliked(checkinId, msg.sender);
    }

    /**
     * @dev Unmeh a checkin (only non-owners can unmeh)
     * @param checkinId The ID of the checkin to unmeh
     */
    function unmehCheckin(uint256 checkinId) external {
        require(checkinId > 0 && checkinId <= _checkinIds, "Invalid checkin ID");
        require(msg.sender != owner(), "Organizer cannot unmeh checkins");
        require(userMehedCheckin[msg.sender][checkinId], "Have not mehed this checkin");
        
        Checkin storage checkinData = checkins[checkinId];
        checkinData.mehs--;
        userMehedCheckin[msg.sender][checkinId] = false;
        
        // Recalculate meh threshold since we removed a meh
        if (!checkinData.isLikedByOrganizer) {
            uint256 totalVotes = checkinData.likes + checkinData.mehs;
            if (totalVotes > 0) {
                uint256 mehPercentage = (checkinData.mehs * 100) / registeredUsers.length;
                if (mehPercentage < MEH_THRESHOLD_PERCENTAGE) {
                    checkinData.isValid = true;
                }
            } else {
                // No votes left, checkin is valid
                checkinData.isValid = true;
            }
        }
        
        emit CheckinUnmehed(checkinId, msg.sender);
    }

    /**
     * @dev Check if user has liked a specific checkin
     * @param user The user address
     * @param checkinId The checkin ID
     * @return Whether user has liked the checkin
     */
    function hasUserLikedCheckin(address user, uint256 checkinId) external view returns (bool) {
        return userLikedCheckin[user][checkinId];
    }

    /**
     * @dev Check if user has mehed a specific checkin
     * @param user The user address
     * @param checkinId The checkin ID
     * @return Whether user has mehed the checkin
     */
    function hasUserMehedCheckin(address user, uint256 checkinId) external view returns (bool) {
        return userMehedCheckin[user][checkinId];
    }

    /**
     * @dev Check and block users who missed 2 checkins in a week
     * @param user The user to check
     */
    function checkAndBlockUser(address user) external onlyOwner {
        User storage userData = users[user];
        uint256 currentWeek = getCurrentWeek();
        
        if (userData.notCheckinTimesInaWeek > 2) {
            userData.isBlocked = true;
            emit UserBlocked(user, currentWeek);
        }
    }

    /**
     * @dev Automatically check and block users every 24 hours
     * Can be called by anyone, but only executes if 24 hours have passed
     * Checks userCheckins mapping to determine missed days in all weeks
     */
    function performAutoCheck() external {
        require(getRealTime() >= lastAutoCheckTime + AUTO_CHECK_INTERVAL, "Auto check not due yet");
        
        uint256 usersChecked = 0;
        uint256 usersBlocked = 0;
        uint256 currentWeek = getCurrentWeek();
        
        for (uint256 i = 0; i < registeredUsers.length; i++) {
            bool userAlreadyBlocked = false;
            address user = registeredUsers[i];
            User storage userData = users[user];
            
            // Skip if user is already blocked
            if (userData.isBlocked) {
                userAlreadyBlocked = true;
            }
            
            usersChecked++;
            
            // Check all weeks from the deployment week to current week
            bool shouldBlock = false;
            uint256 currentDay = getCurrentDay();
            uint256 deploymentWeek = 0; // Week 0 is the deployment week
            for (uint256 week = deploymentWeek; week <= currentWeek; week++) {
                uint256 weekStartDay = week * DAYS_IN_WEEK;
                uint256 weekEndDay = weekStartDay + DAYS_IN_WEEK - 1;
                
                // Ensure weekEndDay doesn't exceed current day
                if (weekEndDay > currentDay) {
                    weekEndDay = currentDay;
                }
                
                // Count missed days in this week
                uint256 missedDays = 0;
                for (uint256 day = weekStartDay; day <= weekEndDay; day++) {
                    uint256 checkinId = userCheckins[user][day];
                    if (checkinId == 0) {
                        // No checkin for this day
                        missedDays++;
                    } else {
                        // Check if the checkin is valid (not invalidated by mehs)
                        Checkin storage checkinData = checkins[checkinId];
                        if (!checkinData.isValid) {
                            // Checkin was invalidated, count as missed day
                            missedDays++;
                        }
                    }
                }
                
                // If user missed 2 or more days in any week, they should be blocked
                if (missedDays > ALLOWED_MISSING_CHECKINS_PER_WEEK) {
                    shouldBlock = true;
                    break; // No need to check other weeks if we found a violation
                }
            }
            
            // Block user if they missed 2 or more days in any week
            if (shouldBlock) {
                if(!userAlreadyBlocked){
                    userData.isBlocked = true;
                    usersBlocked++;
                    emit UserBlocked(user, currentWeek);
                }
            }else {
                if(userAlreadyBlocked){
                    userData.isBlocked = false;
                }
            }

            
        }
        
        lastAutoCheckTime = getRealTime();
        emit AutoCheckPerformed(getRealTime(), usersChecked, usersBlocked);
    }

    /**
     * @dev Check if auto check is due
     * @return Whether auto check can be performed
     */
    function isAutoCheckDue() external view returns (bool) {
        return getRealTime() >= lastAutoCheckTime + AUTO_CHECK_INTERVAL;
    }

    /**
     * @dev Get time until next auto check
     * @return Seconds until next auto check
     */
    function getTimeUntilNextAutoCheck() external view returns (uint256) {
        if (getRealTime() >= lastAutoCheckTime + AUTO_CHECK_INTERVAL) {
            return 0;
        }
        return (lastAutoCheckTime + AUTO_CHECK_INTERVAL) - getRealTime();
    }

    /**
     * @dev Get all registered users
     * @return Array of registered user addresses
     */
    function getRegisteredUsers() external view returns (address[] memory) {
        return registeredUsers;
    }

    /**
     * @dev Get count of registered users
     * @return Number of registered users
     */
    function getRegisteredUserCount() external view returns (uint256) {
        return registeredUsers.length;
    }

    /**
     * @dev Unblock a user (only organizer)
     * @param user The user to unblock
     */
    function unblockUser(address user) external onlyOwner {
        require(users[user].isBlocked, "User is not blocked");
        users[user].isBlocked = false;
        users[user].notCheckinTimesInaWeek = 0;
        users[user].checkInToday = false;
        emit UserUnblocked(user);
    }

    /**
     * @dev Get all checkins for a specific user
     * @param user The user address
     * @return checkinIds Array of checkin IDs
     */
    function getUserCheckins(address user) external view returns (uint256[] memory) {
        uint256[] memory checkinIds = new uint256[](users[user].totalCheckins);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= _checkinIds; i++) {
            if (checkins[i].user == user) {
                checkinIds[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        assembly {
            mstore(checkinIds, count)
        }
        
        return checkinIds;
    }

    /**
     * @dev Get all checkins (for review purposes)
     * @return checkinIds Array of all checkin IDs
     */
    function getAllCheckins() external view returns (uint256[] memory) {
        uint256[] memory checkinIds = new uint256[](_checkinIds);
        
        for (uint256 i = 1; i <= _checkinIds; i++) {
            checkinIds[i - 1] = i;
        }
        
        return checkinIds;
    }

    /**
     * @dev Get checkin details
     * @param checkinId The checkin ID
     * @return The checkin struct
     */
    function getCheckin(uint256 checkinId) external view returns (Checkin memory) {
        require(checkinId > 0 && checkinId <= _checkinIds, "Invalid checkin ID");
        return checkins[checkinId];
    }

    /**
     * @dev Get user status
     * @param user The user address
     * @return userAddress User address
     * @return totalCheckins Total number of checkins
     * @return lastCheckinWeek Last checkin week
     * @return isBlocked Whether user is blocked
     * @return notCheckinTimesInaWeek Number of missed check-ins in current week
     * @return checkInToday Whether user checked in today
     */
    function getUserStatus(address user) external view returns (
        address userAddress,
        uint256 totalCheckins,
        uint256 lastCheckinWeek,
        bool isBlocked,
        uint256 notCheckinTimesInaWeek,
        bool checkInToday
    ) {
        User storage userData = users[user];
        return (
            userData.userAddress,
            userData.totalCheckins,
            userData.lastCheckinWeek,
            userData.isBlocked,
            userData.notCheckinTimesInaWeek,
            userData.checkInToday
        );
    }

    /**
     * @dev Check if user has checked in for a specific week
     * @param user The user address
     * @param week The week number
     * @return Whether user checked in that week
     */
    function hasCheckedInWeek(address user, uint256 week) external view returns (bool) {
        return users[user].weeklyCheckins[week];
    }

    // Helper functions
    function getCurrentWeek() public view returns (uint256) {
        return (getRealTime() - deploymentTimestamp) / (DAYS_IN_WEEK * SECONDS_IN_DAY);
    }

    function getCurrentDay() public view returns (uint256) {
        return (getRealTime() - deploymentTimestamp) / SECONDS_IN_DAY;
    }

    function getWeekFromTimestamp(uint256 timestamp) public view returns (uint256) {
        return (timestamp - deploymentTimestamp) / (DAYS_IN_WEEK * SECONDS_IN_DAY);
    }

    function getTotalCheckins() external view returns (uint256) {
        return _checkinIds;
    }

    /**
     * @dev Reset daily check-in flag for a user (for testing purposes)
     * @param user The user address
     */
    function resetDailyCheckinFlag(address user) external onlyOwner {
        users[user].checkInToday = false;
    }
}
