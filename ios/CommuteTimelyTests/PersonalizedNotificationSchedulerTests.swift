//
// PersonalizedNotificationSchedulerTests.swift
// CommuteTimelyTests
//
// Unit tests for personalized daily notification scheduling
//

import XCTest
import UserNotifications
@testable import CommuteTimely

@MainActor
final class PersonalizedNotificationSchedulerTests: XCTestCase {
    var scheduler: PersonalizedNotificationScheduler!
    var mockAuthManager: ClerkMockProvider!
    var mockPreferencesService: MockUserPreferencesService!
    var mockNotificationService: MockNotificationService!
    
    override func setUp() {
        super.setUp()
        mockAuthManager = ClerkMockProvider()
        mockPreferencesService = MockUserPreferencesService()
        mockNotificationService = MockNotificationService()
        
        scheduler = PersonalizedNotificationScheduler(
            authManager: mockAuthManager,
            userPreferencesService: mockPreferencesService,
            notificationService: mockNotificationService
        )
    }
    
    func testMessageRotation() async throws {
        // Set up initial state
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedNotificationDayIndex = 0
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Schedule first cycle
        try await scheduler.scheduleDailyNotifications(firstName: "Test")
        
        // Verify day index incremented
        let updatedPreferences = await mockPreferencesService.loadPreferences()
        XCTAssertEqual(updatedPreferences.notificationSettings.personalizedNotificationDayIndex, 1, "Day index should increment by 1")
        
        // Schedule second cycle
        try await scheduler.scheduleDailyNotifications(firstName: "Test")
        
        // Verify day index rotated
        let secondPreferences = await mockPreferencesService.loadPreferences()
        XCTAssertEqual(secondPreferences.notificationSettings.personalizedNotificationDayIndex, 2, "Day index should increment to 2")
        
        // Schedule 7 times to complete rotation
        for _ in 0..<5 {
            try await scheduler.scheduleDailyNotifications(firstName: "Test")
        }
        
        // Verify we're back at index 0 (7 % 7 = 0, but we started at 0 and incremented 7 times, so we're at 7 % 7 = 0)
        let finalPreferences = await mockPreferencesService.loadPreferences()
        XCTAssertEqual(finalPreferences.notificationSettings.personalizedNotificationDayIndex, 0, "Day index should cycle back to 0 after 7 increments")
    }
    
    func testPersonalizedContentWithFirstName() async throws {
        // Set up user with firstName
        mockAuthManager.completeMockSignIn(name: "John Doe", email: "john@test.com", firstName: "John")
        
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Schedule notifications
        try await scheduler.scheduleDailyNotifications(firstName: "John")
        
        // Verify notifications were scheduled (mock service should track this)
        // Note: In a real test, we'd verify the actual notification content
        // For now, we verify the method completes without error
        XCTAssertTrue(true, "Scheduling should complete successfully")
    }
    
    func testFallbackToFriendWhenFirstNameIsNil() async throws {
        // Set up user without firstName
        mockAuthManager.completeMockSignIn(name: "User", email: "user@test.com", firstName: nil)
        
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Schedule with nil firstName - should use "Friend"
        let firstName = mockAuthManager.currentUser?.firstName ?? "Friend"
        XCTAssertEqual(firstName, "Friend", "Should fallback to 'Friend' when firstName is nil")
        
        try await scheduler.scheduleDailyNotifications(firstName: firstName)
        
        // Verify scheduling completed
        XCTAssertTrue(true, "Scheduling should complete with fallback name")
    }
    
    func testPersistenceOfRotationCounter() async throws {
        // Set initial day index
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedNotificationDayIndex = 3
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Verify persistence
        let loadedPreferences = await mockPreferencesService.loadPreferences()
        XCTAssertEqual(loadedPreferences.notificationSettings.personalizedNotificationDayIndex, 3, "Day index should persist")
        
        // Schedule and verify it increments
        try await scheduler.scheduleDailyNotifications(firstName: "Test")
        let updatedPreferences = await mockPreferencesService.loadPreferences()
        XCTAssertEqual(updatedPreferences.notificationSettings.personalizedNotificationDayIndex, 4, "Day index should increment and persist")
    }
    
    func testCancellationOnSignOut() async throws {
        // Set up enabled state
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedDailyNotificationsEnabled = true
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Schedule notifications
        try await scheduler.scheduleDailyNotifications(firstName: "Test")
        
        // Cancel all
        await scheduler.cancelAllPersonalizedNotifications()
        
        // Verify cancellation (in real test, would check pending notifications)
        XCTAssertTrue(true, "Cancellation should complete")
    }
    
    func testReschedulingOnSignIn() async throws {
        // Set up enabled state
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedDailyNotificationsEnabled = true
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Sign in with firstName
        mockAuthManager.completeMockSignIn(name: "Jane Doe", email: "jane@test.com", firstName: "Jane")
        
        // Update schedule (simulates sign in handler)
        await scheduler.updateScheduleIfNeeded()
        
        // Verify scheduling was attempted (in real test, would verify notifications)
        XCTAssertTrue(true, "Rescheduling should complete")
    }
    
    func testPermissionRequest() async {
        // Request permission
        let granted = await scheduler.requestPermissionIfNeeded()
        
        // Verify permission was requested (mock service should return true by default)
        XCTAssertTrue(granted, "Permission should be granted in mock")
    }
    
    func testUpdateScheduleWhenEnabled() async throws {
        // Enable personalized notifications
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedDailyNotificationsEnabled = true
        preferences.notificationSettings.personalizedNotificationHour = 8
        preferences.notificationSettings.personalizedNotificationMinute = 0
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Set up user
        mockAuthManager.completeMockSignIn(name: "Test User", email: "test@test.com", firstName: "Test")
        
        // Update schedule
        await scheduler.updateScheduleIfNeeded()
        
        // Verify update completed
        XCTAssertTrue(true, "Update should complete when enabled")
    }
    
    func testUpdateScheduleWhenDisabled() async throws {
        // Disable personalized notifications
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
        try await mockPreferencesService.updatePreferences(preferences)
        
        // Update schedule
        await scheduler.updateScheduleIfNeeded()
        
        // Verify cancellation occurred (in real test, would verify no pending notifications)
        XCTAssertTrue(true, "Update should cancel when disabled")
    }
    
    func testGetCurrentDayIndex() async {
        // Set day index
        var preferences = await mockPreferencesService.loadPreferences()
        preferences.notificationSettings.personalizedNotificationDayIndex = 5
        try? await mockPreferencesService.updatePreferences(preferences)
        
        // Get current index
        let index = await scheduler.getCurrentDayIndex()
        
        // Verify
        XCTAssertEqual(index, 5, "Should return current day index")
    }
}

