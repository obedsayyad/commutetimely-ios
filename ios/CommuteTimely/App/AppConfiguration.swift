//
// AppConfiguration.swift
// CommuteTimely
//
// Central configuration management for API keys and environment settings
//

import Foundation
import StoreKit

enum AppConfiguration {
    
    // MARK: - API Keys
    
    static var mapboxAccessToken: String {
        value(for: "MAPBOX_ACCESS_TOKEN")
    }
    
    static var weatherbitAPIKey: String {
        value(for: "WEATHERBIT_API_KEY")
    }
    
    static var mixpanelToken: String {
        value(for: "MIXPANEL_TOKEN")
    }
    
    static var predictionServerURL: String {
        value(for: "PREDICTION_SERVER_URL")
    }
    
    static var authServerURL: String {
        value(for: "AUTH_SERVER_URL")
    }
    
    static var clerkPublishableKey: String {
        value(for: "CLERK_PUBLISHABLE_KEY")
    }
    
    static var clerkFrontendAPI: String {
        value(for: "CLERK_FRONTEND_API")
    }
    
    // MARK: - Environment Detection
    
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isTestFlight: Bool {
        if #available(iOS 18.0, *) {
            return StoreKitEnvironmentHelper.isTestFlight
        } else {
            return legacyReceiptIsTestFlight()
        }
    }
    
    static var isProduction: Bool {
        !isDebug && !isTestFlight
    }
    
    static var useClerkMock: Bool {
        if let envValue = ProcessInfo.processInfo.environment["COMMUTETIMELY_USE_CLERK_MOCK"] {
            if let explicit = Bool(envValue) {
                return explicit
            }
            if truthyStrings.contains(envValue.lowercased()) {
                return true
            }
        }
        return boolValue(for: "COMMUTETIMELY_USE_CLERK_MOCK")
    }
    
    static var isPredictionVerboseLoggingEnabled: Bool {
        if let envValue = ProcessInfo.processInfo.environment["COMMUTETIMELY_PREDICTION_VERBOSE"] {
            return truthyStrings.contains(envValue.lowercased())
        }
        return boolValue(for: "PREDICTION_VERBOSE_LOGGING", default: false)
    }
    
    // MARK: - App Info
    
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.commutetimely.app"
    }
    
    // MARK: - Private Helper
    
    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty,
              !value.contains("YOUR_") else {
            if isDebug {
                print("⚠️ Missing configuration value for key: \(key)")
                return "missing_\(key.lowercased())"
            }
            fatalError("Missing required configuration value for key: \(key)")
        }
        return value
    }
    
    private static func boolValue(for key: String, default defaultValue: Bool = false) -> Bool {
        guard let rawValue = Bundle.main.infoDictionary?[key] else {
            return defaultValue
        }
        if let stringValue = rawValue as? String {
            return truthyStrings.contains(stringValue.lowercased())
        }
        if let numberValue = rawValue as? NSNumber {
            return numberValue.boolValue
        }
        return defaultValue
    }
    
    private static let truthyStrings: Set<String> = ["1", "true", "yes"]
}

// MARK: - TestFlight Detection Helpers

@available(iOS, introduced: 11.0, deprecated: 18.0, message: "Use StoreKitEnvironmentHelper above iOS 18")
private extension AppConfiguration {
    static func legacyReceiptIsTestFlight() -> Bool {
        if #available(iOS 18.0, *) {
            return false
        }
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
    }
}

@available(iOS 18.0, *)
private enum StoreKitEnvironmentHelper {
    static var isTestFlight: Bool {
        if let cachedResult = cachedResult {
            return cachedResult
        }
        
        let group = DispatchGroup()
        group.enter()
        
        Task {
            cachedResult = await fetchIsTestFlight()
            group.leave()
        }
        
        group.wait()
        return cachedResult ?? false
    }
    
    private static func fetchIsTestFlight() async -> Bool {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                return transaction.environment == .sandbox
            case .unverified:
                return false
            }
        } catch {
            return false
        }
    }
    
    private static var cachedResult: Bool?
}

