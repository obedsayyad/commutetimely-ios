//
// TripCreationFlowTests.swift
// CommuteTimelyUITests
//
// UI tests for trip creation flow
//

import XCTest

final class TripCreationFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testOpenTripCreation() throws {
        // Given: User is on main screen
        let mainScreen = app.navigationBars["My Trips"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 2))
        
        // When: User taps add trip button
        let addButton = app.buttons.matching(identifier: "plus.circle.fill").firstMatch
        XCTAssertTrue(addButton.exists)
        addButton.tap()
        
        // Then: Trip planner should open
        let tripPlannerTitle = app.navigationBars["New Trip"]
        XCTAssertTrue(tripPlannerTitle.waitForExistence(timeout: 2))
    }
    
    func testSearchDestination() throws {
        // Given: User opens trip creation
        openTripCreation()
        
        // When: User searches for destination
        let searchField = app.textFields["Search for a place"]
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("San Francisco")
        
        // Then: Search results should appear
        // (This would need mock data in UI test mode)
        XCTAssertTrue(searchField.value as? String == "San Francisco")
    }
    
    func testCancelTripCreation() throws {
        // Given: User opens trip creation
        openTripCreation()
        
        // When: User taps cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
        
        // Then: Should return to main screen
        let mainScreen = app.navigationBars["My Trips"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 2))
    }
    
    // MARK: - Helpers
    
    private func openTripCreation() {
        let addButton = app.buttons.matching(identifier: "plus.circle.fill").firstMatch
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()
        }
    }
}

