//
// OnboardingFlowTests.swift
// CommuteTimelyUITests
//
// UI tests for onboarding flow
//

import XCTest

final class OnboardingFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launchEnvironment["COMMUTETIMELY_USE_CLERK_MOCK"] = "true"
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testOnboardingWelcomeScreen() throws {
        // Given: App launches for first time
        
        // Then: Welcome screen should appear
        XCTAssertTrue(app.staticTexts["CommuteTimely"].exists)
        XCTAssertTrue(app.staticTexts["Never miss your arrival time"].exists)
        XCTAssertTrue(app.buttons["Get Started"].exists)
    }
    
    func testOnboardingFlowComplete() throws {
        // Given: User is on welcome screen
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 2))
        
        // When: User taps Get Started
        getStartedButton.tap()
        
        // Then: Location permission screen appears
        let locationTitle = app.staticTexts["Enable Location"]
        XCTAssertTrue(locationTitle.waitForExistence(timeout: 2))
        
        // When: User enables location
        let enableLocationButton = app.buttons["Enable Location"]
        if enableLocationButton.exists {
            enableLocationButton.tap()
            
            // Handle system location permission alert
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allowButton = springboard.buttons["Allow While Using App"]
            if allowButton.waitForExistence(timeout: 5) {
                allowButton.tap()
            }
        }
        
        // Then: Notification permission screen appears
        let notificationTitle = app.staticTexts["Stay Notified"]
        XCTAssertTrue(notificationTitle.waitForExistence(timeout: 2))
        
        // When: User enables notifications
        let enableNotificationsButton = app.buttons["Enable Notifications"]
        if enableNotificationsButton.exists {
            enableNotificationsButton.tap()
            
            // Handle system notification permission alert
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allowButton = springboard.buttons["Allow"]
            if allowButton.waitForExistence(timeout: 5) {
                allowButton.tap()
            }
        }
        
        // Then: Main app screen should appear
        // (Adjust based on your actual main screen)
        let mainScreen = app.navigationBars["My Trips"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 3))
    }
    
    func testOnboardingCanSkipNotifications() throws {
        // Given: User completes location step
        app.buttons["Get Started"].tap()
        
        let enableLocationButton = app.buttons["Enable Location"]
        if enableLocationButton.waitForExistence(timeout: 2) {
            enableLocationButton.tap()
        }
        
        // When: User skips notifications
        let skipButton = app.buttons["Skip for Now"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }
        
        // Then: Should still reach main screen
        let mainScreen = app.navigationBars["My Trips"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 3))
    }
}

