//
// ThemeManager.swift
// CommuteTimely
//
// Theme management with system/light/dark mode support
//

import Foundation
import SwiftUI
import Combine

public enum ThemeMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
    
    public var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    public var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
public class ThemeManager: ObservableObject {
    @Published public var currentTheme: ThemeMode {
        didSet {
            saveTheme()
            notifyThemeChange(from: oldValue, to: currentTheme)
        }
    }
    
    private let userDefaults: UserDefaults
    private let storageKey = "app_theme_preference"
    private var analyticsService: AnalyticsServiceProtocol?
    
    init(
        userDefaults: UserDefaults = .standard,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.userDefaults = userDefaults
        self.analyticsService = analyticsService
        
        // Load saved theme or default to system
        if let savedTheme = userDefaults.string(forKey: storageKey),
           let theme = ThemeMode(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }
    }
    
    public func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
    }
    
    public func toggleTheme() {
        switch currentTheme {
        case .system:
            currentTheme = .light
        case .light:
            currentTheme = .dark
        case .dark:
            currentTheme = .system
        }
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: storageKey)
    }
    
    private func notifyThemeChange(from oldTheme: ThemeMode, to newTheme: ThemeMode) {
        // Analytics event
        analyticsService?.trackEvent(
            .themeChanged(
                from: oldTheme.rawValue,
                to: newTheme.rawValue
            )
        )
    }
}

// MARK: - View Extension

public extension View {
    /// Apply the current theme to this view
    func applyTheme(_ themeManager: ThemeManager) -> some View {
        self.preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager()
}

public extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

