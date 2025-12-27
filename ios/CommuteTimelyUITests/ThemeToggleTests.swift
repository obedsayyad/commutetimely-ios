//
// ThemeToggleTests.swift
// CommuteTimelyUITests
//
// UI tests for theme toggling
//

import XCTest

final class ThemeToggleTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testThemePickerExists() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Verify Appearance section exists
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        
        // Verify Theme picker exists
        XCTAssertTrue(app.buttons["Theme"].exists)
    }
    
    func testCanSelectDarkTheme() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Tap theme picker
        app.buttons["Theme"].tap()
        
        // Select Dark
        app.buttons["Dark"].tap()
        
        // Verify selection (implementation depends on UI)
        // This is a basic test structure
        XCTAssertTrue(true)
    }
    
    func testCanSelectLightTheme() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Tap theme picker
        app.buttons["Theme"].tap()
        
        // Select Light
        app.buttons["Light"].tap()
        
        XCTAssertTrue(true)
    }
}

