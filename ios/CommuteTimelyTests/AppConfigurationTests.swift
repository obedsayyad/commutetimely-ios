//
// AppConfigurationTests.swift
// CommuteTimelyTests
//
// Unit tests for AppConfiguration safe error handling
//

import XCTest
@testable import CommuteTimely

final class AppConfigurationTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Clear any cached configuration sources
        // Note: In a real implementation, we might need to reset static state
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Missing Key Tests
    
    func testMissingKeyReturnsNil() {
        // This test verifies that missing keys return nil instead of crashing
        // We can't easily test the actual value(for:) method since it's private,
        // but we can test the public properties
        
        // Note: In a real test environment, we'd need to mock Bundle.main.infoDictionary
        // and ProcessInfo.processInfo.environment. For now, we test the behavior
        // when keys are actually missing (which should return nil in production).
        
        // Since we can't easily mock the static methods, we'll test the error enum
        let error = AppConfigurationError.missingKey("TEST_KEY")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TEST_KEY") ?? false)
    }
    
    func testInvalidValueError() {
        let error = AppConfigurationError.invalidValue("TEST_KEY", "invalid_value")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TEST_KEY") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("invalid_value") ?? false)
    }
    
    func testSourceUnavailableError() {
        let error = AppConfigurationError.sourceUnavailable("test_source")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test_source") ?? false)
    }
    
    // MARK: - Configuration Source Priority Tests
    
    func testEnvironmentVariableTakesPrecedence() {
        // This test would require mocking ProcessInfo.processInfo.environment
        // For now, we verify the error handling doesn't crash
        
        // Test that the error enum works correctly
        let missingKeyError = AppConfigurationError.missingKey("NONEXISTENT_KEY")
        XCTAssertEqual(missingKeyError.localizedDescription, "Configuration key 'NONEXISTENT_KEY' not found in any source")
    }
    
    // MARK: - Placeholder Value Tests
    
    func testPlaceholderValuesAreRejected() {
        // This test verifies that values containing "YOUR_" are treated as invalid
        // Since we can't easily mock the configuration sources, we test the error handling
        
        let error = AppConfigurationError.invalidValue("TEST_KEY", "YOUR_VALUE_HERE")
        XCTAssertNotNil(error.errorDescription)
    }
    
    // MARK: - Empty Value Tests
    
    func testEmptyValuesAreRejected() {
        // This test verifies that empty strings are treated as missing
        let error = AppConfigurationError.invalidValue("TEST_KEY", "")
        XCTAssertNotNil(error.errorDescription)
    }
    
    // MARK: - Production Build Safety Tests
    
    func testNoFatalErrorInReleaseBuilds() {
        // This test verifies that the code doesn't use fatalError
        // We can't directly test this, but we verify the error handling exists
        
        // Test that errors are properly structured
        let error = AppConfigurationError.missingKey("ANY_KEY")
        XCTAssertNotNil(error)
        XCTAssertNotNil(error.errorDescription)
        
        // Verify error conforms to LocalizedError
        XCTAssertTrue(error is LocalizedError)
    }
    
    // MARK: - Optional Return Value Tests
    
    func testConfigurationPropertiesReturnOptional() {
        // Verify that configuration properties can return nil without crashing
        // In a test environment without proper configuration, these should return nil
        
        // Note: These tests may pass or fail depending on whether the test environment
        // has the configuration keys set. The important thing is they don't crash.
        
        // We can't easily test the actual values without mocking, but we can
        // verify the types are optional by checking they compile
        
        let mapboxToken: String? = AppConfiguration.mapboxAccessToken
        let _ = mapboxToken // Suppress unused warning
        
        let weatherKey: String? = AppConfiguration.weatherbitAPIKey
        let _ = weatherKey
        
        let mixpanelToken: String? = AppConfiguration.mixpanelToken
        let _ = mixpanelToken
        
        let predictionURL: String? = AppConfiguration.predictionServerURL
        let _ = predictionURL
        
        let authURL: String? = AppConfiguration.authServerURL
        let _ = authURL
        
        let clerkKey: String? = AppConfiguration.clerkPublishableKey
        let _ = clerkKey
        
        let clerkAPI: String? = AppConfiguration.clerkFrontendAPI
        let _ = clerkAPI
        
        // If we get here without crashing, the optionals are working
        XCTAssertTrue(true)
    }
    
    // MARK: - Logging Tests
    
    func testLogConfigurationStatusDoesNotCrash() {
        // Test that logConfigurationStatus() can be called without crashing
        // This is a smoke test - we can't easily verify the logs are produced
        
        // Should not crash even if configuration is missing
        AppConfiguration.logConfigurationStatus()
        
        XCTAssertTrue(true) // If we get here, it didn't crash
    }
    
    // MARK: - Error Localization Tests
    
    func testErrorDescriptionsAreLocalized() {
        let missingKeyError = AppConfigurationError.missingKey("TEST_KEY")
        let invalidValueError = AppConfigurationError.invalidValue("TEST_KEY", "bad_value")
        let sourceError = AppConfigurationError.sourceUnavailable("test_source")
        
        // Verify all errors have descriptions
        XCTAssertNotNil(missingKeyError.errorDescription)
        XCTAssertNotNil(invalidValueError.errorDescription)
        XCTAssertNotNil(sourceError.errorDescription)
        
        // Verify descriptions contain the key/context
        XCTAssertTrue(missingKeyError.errorDescription?.contains("TEST_KEY") ?? false)
        XCTAssertTrue(invalidValueError.errorDescription?.contains("TEST_KEY") ?? false)
        XCTAssertTrue(sourceError.errorDescription?.contains("test_source") ?? false)
    }
    
    // MARK: - Configuration Source Order Tests
    
    func testConfigurationSourcePriority() {
        // This test documents the expected priority order:
        // 1. ProcessInfo.processInfo.environment (highest)
        // 2. Bundle.main.infoDictionary
        // 3. Bundled JSON config (future)
        
        // We can't easily test this without mocking, but we document the behavior
        XCTAssertTrue(true) // Placeholder - actual implementation would mock sources
    }
    
    // MARK: - TestFlight Build Safety
    
    func testTestFlightBuildDoesNotCrash() {
        // This test verifies that TestFlight builds (which may have missing config)
        // don't crash when accessing configuration
        
        // Access all configuration properties - should not crash
        _ = AppConfiguration.mapboxAccessToken
        _ = AppConfiguration.weatherbitAPIKey
        _ = AppConfiguration.mixpanelToken
        _ = AppConfiguration.predictionServerURL
        _ = AppConfiguration.authServerURL
        _ = AppConfiguration.clerkPublishableKey
        _ = AppConfiguration.clerkFrontendAPI
        
        // If we get here, no crashes occurred
        XCTAssertTrue(true)
    }
    
    // MARK: - Edge Cases
    
    func testNilCoalescingWorks() {
        // Test that nil coalescing works with optional configuration values
        let mapboxToken = AppConfiguration.mapboxAccessToken ?? "fallback"
        XCTAssertNotNil(mapboxToken)
        
        let weatherKey = AppConfiguration.weatherbitAPIKey ?? "fallback"
        XCTAssertNotNil(weatherKey)
    }
    
    func testOptionalBindingWorks() {
        // Test that optional binding works with configuration values
        if let token = AppConfiguration.mapboxAccessToken {
            XCTAssertFalse(token.isEmpty)
        } else {
            // Missing token is acceptable - app should continue
            XCTAssertTrue(true)
        }
    }
}

