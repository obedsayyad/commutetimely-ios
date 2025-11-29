//
// AuthFlowTests.swift
// CommuteTimelyUITests
//
// UI tests for authentication flows
//

import XCTest

final class AuthFlowTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment["COMMUTETIMELY_USE_CLERK_MOCK"] = "true"
        app.launch()
    }
    
    func testAuthLandingViewAppears() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Tap sign in
        if app.buttons["Sign in to sync"].exists {
            app.buttons["Sign in to sync"].tap()
            
            // Verify auth landing appears
            XCTAssertTrue(app.staticTexts["Back up your trips"].waitForExistence(timeout: 2))
        }
    }
    
    func testClerkButtonVisible() throws {
        app.tabBars.buttons["Settings"].tap()
        if app.buttons["Sign in to sync"].exists {
            app.buttons["Sign in to sync"].tap()
            XCTAssertTrue(app.buttons["Sign in with Clerk"].waitForExistence(timeout: 2))
        }
    }
    
    func testMockSignInFlow() throws {
        app.tabBars.buttons["Settings"].tap()
        guard app.buttons["Sign in to sync"].exists else { return }
        
        app.buttons["Sign in to sync"].tap()
        let mockButton = app.buttons["Complete mock sign-in"]
        XCTAssertTrue(mockButton.waitForExistence(timeout: 2))
        mockButton.tap()
        
        // Dismiss landing and verify profile shows signed-in state
        app.buttons["Maybe later"].tap()
        XCTAssertFalse(app.buttons["Sign in to sync"].exists)
        
        // Verify sign out button exists in profile view
        app.buttons["Sign Out"].tap()
        XCTAssertTrue(app.buttons["Sign in to sync"].waitForExistence(timeout: 2))
    }
}

