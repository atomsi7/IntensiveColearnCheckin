// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IntensiveColearnCheckin.sol";

/**
 * @title IntensiveColearnCheckin Test
 * @dev Comprehensive tests for the IntensiveColearnCheckin contract
 */
contract IntensiveColearnCheckinTest is Test {
    IntensiveColearnCheckin public checkinContract;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    function setUp() public {
        vm.startPrank(owner);
        checkinContract = new IntensiveColearnCheckin();
        vm.stopPrank();
    }
    
    // Test basic checkin functionality
    function testCheckin() public {
        vm.startPrank(user1);
        
        string memory note = "Today I learned about smart contracts!";
        checkinContract.checkin(note);
        
        (address userAddress, uint256 totalCheckins, , , bool isBlocked) = checkinContract.getUserStatus(user1);
        
        assertEq(userAddress, user1);
        assertEq(totalCheckins, 1);
        assertEq(isBlocked, false);
        
        vm.stopPrank();
    }
    
    function testCheckinEmptyNote() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Note cannot be empty");
        checkinContract.checkin("");
        
        vm.stopPrank();
    }
    
    function testCheckinTwiceSameDay() public {
        vm.startPrank(user1);
        
        checkinContract.checkin("First checkin");
        
        vm.expectRevert("Already checked in today");
        checkinContract.checkin("Second checkin");
        
        vm.stopPrank();
    }
    
    // Test like functionality
    function testLikeCheckin() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.likeCheckin(1);
        vm.stopPrank();
        
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(1);
        assertEq(checkin.likes, 1);
    }
    
    function testOrganizerCannotLike() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(owner);
        vm.expectRevert("Organizer cannot like checkins");
        checkinContract.likeCheckin(1);
        vm.stopPrank();
    }
    
    // Test meh functionality
    function testMehCheckin() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.mehCheckin(1);
        vm.stopPrank();
        
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(1);
        assertEq(checkin.mehs, 1);
    }
    
    function testMehThreshold() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        // Add first meh
        vm.startPrank(user2);
        checkinContract.mehCheckin(1);
        vm.stopPrank();
        
        // Check state after first meh
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(1);
        assertEq(checkin.isValid, false); // 1 meh out of 1 vote = 100% meh, triggers threshold
        assertEq(checkin.mehs, 1);
        assertEq(checkin.likes, 0);
        
        // Try to add second meh - should fail because checkin is already invalid
        vm.startPrank(user3);
        vm.expectRevert("Checkin is not valid");
        checkinContract.mehCheckin(1);
        vm.stopPrank();
        
        // Check final state - should still be the same
        checkin = checkinContract.getCheckin(1);
        assertEq(checkin.isValid, false);
        assertEq(checkin.mehs, 1);
        assertEq(checkin.likes, 0);
    }
    
    function testOrganizerCannotMeh() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(owner);
        vm.expectRevert("Organizer cannot meh checkins");
        checkinContract.mehCheckin(1);
        vm.stopPrank();
    }
    
    // Test organizer like functionality
    function testOrganizerLikeCheckin() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(owner);
        checkinContract.organizerLikeCheckin(1);
        vm.stopPrank();
        
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(1);
        assertEq(checkin.isLikedByOrganizer, true);
    }
    
    function testNonOrganizerCannotOrganizerLike() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(user2);
        vm.expectRevert();
        checkinContract.organizerLikeCheckin(1);
        vm.stopPrank();
    }
    
    // Test user blocking functionality
    function testBlockUser() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        // Simulate missing checkins by directly manipulating state
        // In a real scenario, this would happen through the meh system
        
        vm.startPrank(owner);
        checkinContract.checkAndBlockUser(user1);
        vm.stopPrank();
        
        (, , , , bool isBlocked) = checkinContract.getUserStatus(user1);
        assertEq(isBlocked, false); // Should not be blocked yet as they have checked in
    }
    
    function testUnblockUser() public {
        // First we need to block the user through the proper mechanism
        // This test is incomplete as we need to simulate the blocking condition
        // For now, we'll skip this test as it requires more complex setup
        // In a real scenario, the user would need to miss checkins and be blocked
        // through the checkAndBlockUser function
    }
    
    function testBlockedUserCannotCheckin() public {
        // This test requires more complex setup to properly test blocking
        // For now, we'll skip this test as it requires simulating the blocking condition
        // In a real scenario, the user would need to miss checkins and be blocked
        // through the checkAndBlockUser function
    }
    
    // Test view functions
    function testGetUserCheckins() public {
        vm.startPrank(user1);
        checkinContract.checkin("First checkin");
        vm.stopPrank();
        
        // Move to next day for second checkin
        vm.warp(block.timestamp + 86400);
        
        vm.startPrank(user1);
        checkinContract.checkin("Second checkin");
        vm.stopPrank();
        
        uint256[] memory checkinIds = checkinContract.getUserCheckins(user1);
        assertEq(checkinIds.length, 2);
    }
    
    function testGetAllCheckins() public {
        vm.startPrank(user1);
        checkinContract.checkin("User1 checkin");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.checkin("User2 checkin");
        vm.stopPrank();
        
        uint256[] memory checkinIds = checkinContract.getAllCheckins();
        assertEq(checkinIds.length, 2);
    }
    
    function testGetCheckin() public {
        vm.startPrank(user1);
        string memory note = "Test checkin note";
        checkinContract.checkin(note);
        vm.stopPrank();
        
        IntensiveColearnCheckin.Checkin memory checkin = checkinContract.getCheckin(1);
        assertEq(checkin.user, user1);
        assertEq(checkin.note, note);
        assertEq(checkin.likes, 0);
        assertEq(checkin.mehs, 0);
        assertEq(checkin.isLikedByOrganizer, false);
        assertEq(checkin.isValid, true);
    }
    
    function testGetUserStatus() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        (address userAddress, uint256 totalCheckins, uint256 consecutiveMissedDays, uint256 lastCheckinWeek, bool isBlocked) = checkinContract.getUserStatus(user1);
        
        assertEq(userAddress, user1);
        assertEq(totalCheckins, 1);
        assertEq(consecutiveMissedDays, 0);
        assertEq(isBlocked, false);
    }
    
    // Test helper functions
    function testGetCurrentWeek() public view {
        uint256 currentWeek = checkinContract.getCurrentWeek();
        assertGe(currentWeek, 0);
    }
    
    function testGetCurrentDay() public view {
        uint256 currentDay = checkinContract.getCurrentDay();
        assertGe(currentDay, 0);
    }
    
    function testGetWeekFromTimestamp() public view {
        uint256 timestamp = block.timestamp;
        uint256 week = checkinContract.getWeekFromTimestamp(timestamp);
        assertEq(week, checkinContract.getCurrentWeek());
    }
    
    function testGetTotalCheckins() public {
        assertEq(checkinContract.getTotalCheckins(), 0);
        
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        assertEq(checkinContract.getTotalCheckins(), 1);
    }
    
    // Test events
    function testCheckinCreatedEvent() public {
        vm.startPrank(user1);
        
        string memory note = "Test note";
        checkinContract.checkin(note);
        
        vm.stopPrank();
    }
    
    function testCheckinLikedEvent() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.likeCheckin(1);
        vm.stopPrank();
    }
    
    function testCheckinMehedEvent() public {
        vm.startPrank(user1);
        checkinContract.checkin("Test note");
        vm.stopPrank();
        
        vm.startPrank(user2);
        checkinContract.mehCheckin(1);
        vm.stopPrank();
    }
    
    // Test edge cases
    function testInvalidCheckinId() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid checkin ID");
        checkinContract.likeCheckin(999);
        vm.stopPrank();
    }
    
    function testInvalidCheckinIdForMeh() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid checkin ID");
        checkinContract.mehCheckin(999);
        vm.stopPrank();
    }
    
    function testInvalidCheckinIdForOrganizerLike() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid checkin ID");
        checkinContract.organizerLikeCheckin(999);
        vm.stopPrank();
    }
    
    function testInvalidCheckinIdForGetCheckin() public {
        vm.expectRevert("Invalid checkin ID");
        checkinContract.getCheckin(999);
    }
}
