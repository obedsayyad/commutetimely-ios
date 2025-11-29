//
// ThemeManagerTests.swift
// CommuteTimelyTests
//
// Unit tests for ThemeManager
//

import XCTest
@testable import CommuteTimely

@MainActor
final class ThemeManagerTests: XCTestCase {
    
    var themeManager: ThemeManager!
    var userDefaults: UserDefaults!
    
    override func setUp() {
        // Use in-memory UserDefaults for testing
        userDefaults = UserDefaults(suiteName: "test.theme.\(UUID().uuidString)")!
        themeManager = ThemeManager(userDefaults: userDefaults, analyticsService: nil)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: userDefaults.domain)
    }
    
    func testDefaultThemeIsSystem() {
        XCTAssertEqual(themeManager.currentTheme, .system)
    }
    
    func testSetTheme() {
        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.currentTheme, .dark)
    }
    
    func testThemePersistence() {
        // Set theme
        themeManager.setTheme(.light)
        
        // Create new manager with same UserDefaults
        let newManager = ThemeManager(userDefaults: userDefaults, analyticsService: nil)
        
        // Verify theme persisted
        XCTAssertEqual(newManager.currentTheme, .light)
    }
    
    func testToggleTheme() {
        // Start with system
        XCTAssertEqual(themeManager.currentTheme, .system)
        
        // Toggle to light
        themeManager.toggleTheme()
        XCTAssertEqual(themeManager.currentTheme, .light)
        
        // Toggle to dark
        themeManager.toggleTheme()
        XCTAssertEqual(themeManager.currentTheme, .dark)
        
        // Toggle back to system
        themeManager.toggleTheme()
        XCTAssertEqual(themeManager.currentTheme, .system)
    }
    
    func testThemeModeColorScheme() {
        XCTAssertNil(ThemeMode.system.colorScheme)
        XCTAssertEqual(ThemeMode.light.colorScheme, .light)
        XCTAssertEqual(ThemeMode.dark.colorScheme, .dark)
    }
    
    func testThemeModeDisplayNames() {
        XCTAssertEqual(ThemeMode.system.displayName, "System")
        XCTAssertEqual(ThemeMode.light.displayName, "Light")
        XCTAssertEqual(ThemeMode.dark.displayName, "Dark")
    }
}

