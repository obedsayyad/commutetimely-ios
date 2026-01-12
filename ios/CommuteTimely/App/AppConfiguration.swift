//
// AppConfiguration.swift
// CommuteTimely
//
// Central configuration management for API keys and environment settings
//

import Foundation
import StoreKit
import OSLog

// MARK: - Configuration Error

enum AppConfigurationError: LocalizedError {
    case missingKey(String)
    case invalidValue(String, String)
    case sourceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .missingKey(let key):
            return "Configuration key '\(key)' not found in any source"
        case .invalidValue(let key, let value):
            return "Configuration key '\(key)' has invalid value: '\(value)'"
        case .sourceUnavailable(let source):
            return "Configuration source unavailable: \(source)"
        }
    }
}

enum AppConfiguration {
    
    // MARK: - Logging
    
    private static let logger = Logger(subsystem: "com.commutetimely.configuration", category: "AppConfiguration")
    
    // Track which source provided each key for debugging
    private static var configurationSource: [String: ConfigurationSource] = [:]
    
    private enum ConfigurationSource: String {
        case environment = "ProcessInfo.environment"
        case infoPlist = "Bundle.main.infoDictionary"
        case bundledJSON = "Bundled JSON config"
    }
    
    // MARK: - API Keys
    
    static var mapboxAccessToken: String? {
        value(for: "MAPBOX_ACCESS_TOKEN")
    }
    
    static var weatherbitAPIKey: String? {
        value(for: "WEATHERBIT_API_KEY")
    }
    
    static var mixpanelToken: String? {
        value(for: "MIXPANEL_TOKEN")
    }
    
    static var predictionServerURL: String? {
        value(for: "PREDICTION_SERVER_URL")
    }
    
    static var authServerURL: String? {
        value(for: "AUTH_SERVER_URL")
    }
    
    // MARK: - Supabase Configuration (from AppSecrets)
    
    /// Supabase project URL
    /// Configured via AppSecrets.swift
    static var supabaseURL: String {
        AppSecrets.supabaseURL
    }
    
    /// Supabase anonymous (public) key
    /// Configured via AppSecrets.swift
    static var supabaseAnonKey: String {
        AppSecrets.supabaseAnonKey
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
        Bundle.main.bundleIdentifier ?? "com.develentcorp.CommuteTimely"
    }
    
    // MARK: - Legal Documents
    
    /// Privacy Policy URL for App Store compliance
    static var privacyPolicyURL: String {
        "https://www.commutetimely.com/privacy-policy"
    }
    
    /// Terms of Use (EULA) URL for App Store compliance
    static var termsOfUseURL: String {
        "https://www.commutetimely.com/terms-of-service"
    }

    
    // MARK: - Private Helper
    
    /// Safely retrieves a configuration value from multiple sources.
    /// Checks sources in order: ProcessInfo.environment → Bundle.main.infoDictionary
    /// Returns nil if key is not found or value is invalid (empty or placeholder).
    /// Never crashes - logs errors instead.
    private static func value(for key: String) -> String? {
        // Check ProcessInfo.environment first (highest priority - runtime override)
        if let envValue = ProcessInfo.processInfo.environment[key],
           !envValue.isEmpty,
           !envValue.contains("YOUR_") {
            configurationSource[key] = .environment
            logger.info("Configuration key '\(key)' loaded from environment")
            return envValue
        }
        
        // Check Bundle.main.infoDictionary (build-time configuration)
        if let plistValue = Bundle.main.infoDictionary?[key] as? String,
           !plistValue.isEmpty,
           !plistValue.contains("YOUR_") {
            configurationSource[key] = .infoPlist
            logger.info("Configuration key '\(key)' loaded from Info.plist")
            return plistValue
        }
        
        // Key not found or invalid value
        let error = AppConfigurationError.missingKey(key)
        logger.error("\(error.localizedDescription)")
        
        // In debug builds, provide more context
        if isDebug {
            logger.debug("Available environment keys: \(ProcessInfo.processInfo.environment.keys.sorted().joined(separator: ", "))")
            if let infoDict = Bundle.main.infoDictionary {
                logger.debug("Available Info.plist keys: \(infoDict.keys.sorted().joined(separator: ", "))")
            }
        }
        
        return nil
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
    
    // MARK: - Configuration Status Logging
    
    /// Logs the status of all configuration keys, including which source provided each value.
    /// Call this during app initialization for debugging.
    static func logConfigurationStatus() {
        let keys = [
            "MAPBOX_ACCESS_TOKEN",
            "WEATHERBIT_API_KEY",
            "MIXPANEL_TOKEN",
            "PREDICTION_SERVER_URL",
            "AUTH_SERVER_URL"
        ]
        
        logger.info("=== Configuration Status ===")
        
        logger.info("Bundle ID: \(bundleIdentifier)")
        
        for key in keys {
            if let value = value(for: key) {
                let source = configurationSource[key]?.rawValue ?? "unknown"
                // Log first few characters only for security
                let maskedValue = String(value.prefix(8)) + (value.count > 8 ? "..." : "")
                logger.info("✓ \(key): loaded from \(source) (value: \(maskedValue))")
            } else {
                logger.error("✗ \(key): MISSING")
            }
        }
        
        // Log Supabase configuration from AppSecrets
        let supabaseURLMasked = String(supabaseURL.prefix(30)) + "..."
        logger.info("✓ SUPABASE_URL: configured via AppSecrets (value: \(supabaseURLMasked))")
        logger.info("✓ SUPABASE_ANON_KEY: configured via AppSecrets (present)")
        
        logger.info("=== End Configuration Status ===")
    }
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

