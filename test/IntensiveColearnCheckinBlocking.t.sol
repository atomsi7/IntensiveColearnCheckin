// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IntensiveColearnCheckin.sol";

/**
 * @title IntensiveColearnCheckin Blocking Test
 * @dev Tests for blocking scenarios and meh threshold logic
 */
contract IntensiveColearnCheckinBlockingTest is Test {
    IntensiveColearnCheckin public checkinContract;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public user4 = address(0x5);
    address public user5 = address(0x6);
    address public user6 = address(0x7);
    address public user7 = address(0x8);
    
    function setUp() public {
        vm.startPrank(owner);
        checkinContract = new IntensiveColearnCheckin();
        vm.stopPrank();
    }
    
    /**
     * @dev Helper function to skip days and reset daily checkin flags
     */
    function skipDaysAndReset(uint256 daysToSkip) internal {
        for (uint i = 0; i < daysToSkip; i++) {
            vm.prank(owner);
            checkinContract.skipOneDay();
            vm.warp(block.timestamp + 25 hours);
        }
    }
    
    /**
     * @dev Test Scenario 1: User that does not checkin more than 2 days will be blocked
     */
    function testUserBlockedAfterMissingMoreThan2Days() public {
        // Register users first
        vm.startPrank(user1);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Skip 3 days and perform auto checks
        for (uint i = 0; i < 3; i++) {
            vm.prank(owner);
            checkinContract.skipOneDay();
            vm.warp(block.timestamp + 25 hours);
            checkinContract.performAutoCheck();
        }
        
        // User should be blocked after missing more than 2 days
        (,,, bool isBlocked,,) = checkinContract.getUserStatus(user1);
        assertEq(isBlocked, true, "User should be blocked after missing more than 2 days");
        
        // Verify blocked user cannot checkin
        vm.startPrank(user1);
        vm.expectRevert("User is blocked");
        checkinContract.checkin("Should fail");
        vm.stopPrank();
    }
    
    /**
     * @dev Test Scenario 2: When user's checkin is invalid by 67%+ meh, user will be blocked including the missing checkin day
     */
    function testUserBlockedWhenCheckinInvalidatedByMeh() public {
        // Register multiple users to create the 67% threshold scenario
        address[] memory users = new address[](10);
        users[0] = user1; users[1] = user2; users[2] = user3; users[3] = user4; users[4] = user5;
        users[5] = user6; users[6] = user7; users[7] = address(0x9); users[8] = address(0xA); users[9] = address(0xB);
        
        // Register all users
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            checkinContract.checkin("Initial checkin");
            vm.stopPrank();
        }
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 creates a checkin that will be mehed
        vm.startPrank(user1);
        checkinContract.checkin("Controversial checkin");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // 7 out of 10 users meh the checkin (70% meh rate, above 67% threshold)
        for (uint i = 2; i < 9; i++) { // Skip user1 (creator) and user2 (will like)
            vm.startPrank(users[i]);
            checkinContract.mehCheckin(checkinId);
            vm.stopPrank();
        }
        
        // Verify the checkin is invalidated
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should be invalidated by 70% meh rate");
        assertEq(checkin.mehs, 7, "Should have 7 mehs");
        
        // Skip 3 days to trigger blocking mechanism
        for (uint i = 0; i < 3; i++) {
            vm.prank(owner);
            checkinContract.skipOneDay();
            vm.warp(block.timestamp + 25 hours);
            checkinContract.performAutoCheck();
        }
        
        // User1 should be blocked because their checkin was invalidated (counts as missing day)
        (,,, bool isBlocked,,) = checkinContract.getUserStatus(user1);
        assertEq(isBlocked, true, "User should be blocked when their checkin is invalidated by meh");
        
        // Verify blocked user cannot checkin
        vm.startPrank(user1);
        vm.expectRevert("User is blocked");
        checkinContract.checkin("Should fail");
        vm.stopPrank();
    }
    
    /**
     * @dev Test Scenario 3: When user's checkin is invalid by 67%+ meh, but liked by organizer, it's still valid
     */
    function testCheckinRemainsValidWhenLikedByOrganizer() public {
        // Register multiple users
        address[] memory users = new address[](10);
        users[0] = user1; users[1] = user2; users[2] = user3; users[3] = user4; users[4] = user5;
        users[5] = user6; users[6] = user7; users[7] = address(0x9); users[8] = address(0xA); users[9] = address(0xB);
        
        // Register all users
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            checkinContract.checkin("Initial checkin");
            vm.stopPrank();
        }
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 posts a note
        vm.startPrank(user1);
        checkinContract.checkin("User1's note");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // Check initial state
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, true, "Checkin should be valid initially");
        assertEq(checkin.mehs, 0, "Should have 0 mehs initially");
        
        // Mehed by others (7 out of 10 users meh = 70% meh rate, above 67% threshold)
        for (uint i = 2; i < 9; i++) { // Skip user1 (creator) and user2 (will like)
            vm.startPrank(users[i]);
            checkinContract.mehCheckin(checkinId);
            vm.stopPrank();
        }
        
        // Verify the checkin is invalidated by mehs
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should be invalidated by 70% meh rate");
        assertEq(checkin.mehs, 7, "Should have 7 mehs");
        assertEq(checkin.isLikedByOrganizer, false, "Organizer should not have liked yet");
        
        // Perform auto check - check that isValid = false
        vm.prank(owner);
        checkinContract.skipOneDay();
        vm.warp(block.timestamp + 25 hours);
        checkinContract.performAutoCheck();
        
        // Verify checkin is still invalid after auto check
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should remain invalid after auto check");
        
        // Liked by the Owner
        vm.startPrank(owner);
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
        
        // Verify organizer like is recorded and checkin becomes valid
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isLikedByOrganizer, true, "Organizer like should be recorded");
        assertEq(checkin.isValid, true, "Checkin should become valid after organizer like");
        
        // Skip one day
        vm.prank(owner);
        checkinContract.skipOneDay();
        vm.warp(block.timestamp + 25 hours);
        
        // Check that isValid = true
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, true, "Checkin should remain valid after skipping one day");
        assertEq(checkin.isLikedByOrganizer, true, "Organizer like should still be recorded");
        
        // Test completed successfully - the core logic works as expected
        console.log("Test completed: Checkin remains valid when liked by organizer");
    }
    
    /**
     * @dev Test that organizer can like a checkin after it's been mehed
     */
    function testOrganizerCanLikeAfterMeh() public {
        // Register users
        vm.startPrank(user1);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user4);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 creates a checkin
        vm.startPrank(user1);
        checkinContract.checkin("Controversial checkin");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // 3 out of 4 users meh the checkin (75% meh rate, above 67% threshold)
        vm.startPrank(user2);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        vm.startPrank(user4);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        // Verify the checkin is invalidated
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should be invalidated by 75% meh rate");
        
        // Organizer likes the checkin after it's been mehed
        vm.startPrank(owner);
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
        
        // Verify the checkin becomes valid again
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, true, "Checkin should become valid after organizer like");
        assertEq(checkin.isLikedByOrganizer, true, "Organizer like should be recorded");
    }
    
    /**
     * @dev Test that organizer can unlike a checkin, making it invalid again if meh threshold is met
     */
    function testOrganizerUnlikeMakesCheckinInvalidAgain() public {
        // Register users
        vm.startPrank(user1);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user4);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 creates a checkin
        vm.startPrank(user1);
        checkinContract.checkin("Controversial checkin");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // 3 out of 4 users meh the checkin (75% meh rate, above 67% threshold)
        vm.startPrank(user2);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        vm.startPrank(user4);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        // Verify the checkin is invalidated
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should be invalidated by 75% meh rate");
        
        // Organizer likes the checkin
        vm.startPrank(owner);
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
        
        // Verify the checkin becomes valid
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, true, "Checkin should become valid after organizer like");
        
        // Organizer unlikes the checkin
        vm.startPrank(owner);
        checkinContract.unlikeCheckin(checkinId);
        vm.stopPrank();
        
        // Verify the checkin becomes invalid again
        checkin = checkinContract.getCheckin(checkinId);
        assertEq(checkin.isValid, false, "Checkin should become invalid again after organizer unlike");
        assertEq(checkin.isLikedByOrganizer, false, "Organizer like should be removed");
    }
    
    /**
     * @dev Test the complete blocking flow with multiple invalidated checkins
     */
    function testCompleteBlockingFlow() public {
        // Register users
        address[] memory users = new address[](5);
        users[0] = user1; users[1] = user2; users[2] = user3; users[3] = user4; users[4] = user5;
        
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            checkinContract.checkin("Initial checkin");
            vm.stopPrank();
        }
        
        // User1 creates checkins for 3 consecutive days (starting from day 1)
        for (uint i = 0; i < 3; i++) {
            skipDaysAndReset(1);
            vm.startPrank(user1);
            checkinContract.checkin("Daily checkin");
            vm.stopPrank();
        }
        
        // Get the checkin IDs for the 3 checkins (excluding the initial checkin)
        uint256[] memory checkinIds = checkinContract.getUserCheckins(user1);
        assertEq(checkinIds.length, 4, "Should have 4 checkins (1 initial + 3 daily)");
        
        // Invalidate 2 out of 3 daily checkins with mehs (4 out of 5 users meh = 80% meh rate)
        // Skip the first checkin (initial) and invalidate checkins 1 and 2
        for (uint i = 1; i < 3; i++) {
            for (uint j = 1; j < 5; j++) { // Skip user1 (creator)
                vm.startPrank(users[j]);
                checkinContract.mehCheckin(checkinIds[i]);
                vm.stopPrank();
            }
        }
        
        // Verify 2 checkins are invalidated
        IntensiveColearnCheckin.Checkin memory checkin1 = checkinContract.getCheckin(checkinIds[1]);
        IntensiveColearnCheckin.Checkin memory checkin2 = checkinContract.getCheckin(checkinIds[2]);
        IntensiveColearnCheckin.Checkin memory checkin3 = checkinContract.getCheckin(checkinIds[3]);
        
        assertEq(checkin1.isValid, false, "Second checkin should be invalidated");
        assertEq(checkin2.isValid, false, "Third checkin should be invalidated");
        assertEq(checkin3.isValid, true, "Fourth checkin should remain valid");
        
        // Skip 1 more day and perform auto check
        vm.prank(owner);
        checkinContract.skipOneDay();
        vm.warp(block.timestamp + 25 hours);
        checkinContract.performAutoCheck();
        
        // User1 should be blocked because they have 2 invalidated checkins (counts as missing days)
        (,,, bool isBlocked,,) = checkinContract.getUserStatus(user1);
        assertEq(isBlocked, true, "User should be blocked after having 2 invalidated checkins");
        
        // Verify blocked user cannot checkin
        vm.startPrank(user1);
        vm.expectRevert("User is blocked");
        checkinContract.checkin("Should fail");
        vm.stopPrank();
    }
    
    /**
     * @dev Test that users can only like or meh once per checkin
     */
    function testUserCanOnlyLikeOrMehOnce() public {
        // Register users
        vm.startPrank(user1);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 creates a checkin
        vm.startPrank(user1);
        checkinContract.checkin("Test checkin");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // User2 likes the checkin
        vm.startPrank(user2);
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
        
        // User2 tries to like again - should fail
        vm.startPrank(user2);
        vm.expectRevert("Already liked this checkin");
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
        
        // User2 tries to meh the same checkin - should fail
        vm.startPrank(user2);
        vm.expectRevert("Cannot meh a checkin you have liked");
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        // User3 mehs the checkin
        vm.startPrank(user3);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        // User3 tries to meh again - should fail
        vm.startPrank(user3);
        vm.expectRevert("Already mehed this checkin");
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        // User3 tries to like the same checkin - should fail
        vm.startPrank(user3);
        vm.expectRevert("Cannot like a checkin you have mehed");
        checkinContract.likeCheckin(checkinId);
        vm.stopPrank();
    }
    
    /**
     * @dev Test to understand meh threshold calculation
     */
    function testMehThresholdCalculation() public {
        // Register 3 users
        vm.startPrank(user1);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        vm.startPrank(user3);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Skip to next day
        skipDaysAndReset(1);
        
        // User1 creates a checkin
        vm.startPrank(user1);
        checkinContract.checkin("Test checkin");
        vm.stopPrank();
        
        uint256 checkinId = checkinContract.getTotalCheckins();
        
        // Check initial state
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(checkinId);
        console.log("Initial checkin state:");
        console.log("Likes:", checkin.likes);
        console.log("Mehs:", checkin.mehs);
        console.log("IsValid:", checkin.isValid);
        console.log("Registered users:", checkinContract.getRegisteredUserCount());
        
        // User2 mehs the checkin
        vm.startPrank(user2);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        checkin = checkinContract.getCheckin(checkinId);
        console.log("After 1 meh:");
        console.log("Likes:", checkin.likes);
        console.log("Mehs:", checkin.mehs);
        console.log("IsValid:", checkin.isValid);
        console.log("Meh percentage:", (checkin.mehs * 100) / checkinContract.getRegisteredUserCount());
        
        // User3 mehs the checkin
        vm.startPrank(user3);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        checkin = checkinContract.getCheckin(checkinId);
        console.log("After 2 mehs:");
        console.log("Likes:", checkin.likes);
        console.log("Mehs:", checkin.mehs);
        console.log("IsValid:", checkin.isValid);
        console.log("Meh percentage:", (checkin.mehs * 100) / checkinContract.getRegisteredUserCount());
        
        // 2 mehs out of 3 registered users = 66% meh rate, which is below 67% threshold
        assertEq(checkin.isValid, true, "Checkin should remain valid with 66% meh rate (below 67% threshold)");
        
        // Add a 4th user to make the threshold work
        vm.startPrank(user4);
        checkinContract.checkin("Initial checkin");
        vm.stopPrank();
        
        // Now 2 mehs out of 4 registered users = 50% meh rate
        checkin = checkinContract.getCheckin(checkinId);
        console.log("After adding 4th user:");
        console.log("Registered users:", checkinContract.getRegisteredUserCount());
        console.log("Meh percentage:", (checkin.mehs * 100) / checkinContract.getRegisteredUserCount());
        assertEq(checkin.isValid, true, "Checkin should remain valid with 50% meh rate");
        
        // Add a 3rd meh to reach 75% meh rate (3 out of 4 users)
        vm.startPrank(user4);
        checkinContract.mehCheckin(checkinId);
        vm.stopPrank();
        
        checkin = checkinContract.getCheckin(checkinId);
        console.log("After 3 mehs:");
        console.log("Mehs:", checkin.mehs);
        console.log("Meh percentage:", (checkin.mehs * 100) / checkinContract.getRegisteredUserCount());
        assertEq(checkin.isValid, false, "Checkin should be invalidated by 75% meh rate");
    }
}
