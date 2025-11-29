//
// UserPreferencesService.swift
// CommuteTimely
//
// Service for managing user preferences and settings
//

import Foundation
import Combine

protocol UserPreferencesServiceProtocol {
    var preferences: AnyPublisher<UserPreferences, Never> { get }
    
    func loadPreferences() async -> UserPreferences
    func updatePreferences(_ preferences: UserPreferences) async throws
    func updateNotificationSettings(_ settings: NotificationPreferences) async throws
    func updatePrivacySettings(_ settings: PrivacyPreferences) async throws
    func updateDisplaySettings(_ settings: DisplayPreferences) async throws
}

class UserPreferencesService: UserPreferencesServiceProtocol {
    private let preferencesSubject = CurrentValueSubject<UserPreferences, Never>(UserPreferences())
    private let userDefaults: UserDefaults
    private let storageKey = "user_preferences"
    
    var preferences: AnyPublisher<UserPreferences, Never> {
        preferencesSubject.eraseToAnyPublisher()
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        Task {
            let loaded = await loadPreferences()
            preferencesSubject.send(loaded)
        }
    }
    
    func loadPreferences() async -> UserPreferences {
        guard let data = userDefaults.data(forKey: storageKey) else {
            let defaultPreferences = UserPreferences()
            try? await updatePreferences(defaultPreferences)
            return defaultPreferences
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(UserPreferences.self, from: data)
        } catch {
            print("[UserPreferences] Failed to decode preferences: \(error)")
            return UserPreferences()
        }
    }
    
    func updatePreferences(_ preferences: UserPreferences) async throws {
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(preferences)
            userDefaults.set(data, forKey: storageKey)
            preferencesSubject.send(preferences)
        } catch {
            throw PreferencesError.encodingFailed(error)
        }
    }
    
    func updateNotificationSettings(_ settings: NotificationPreferences) async throws {
        var current = await loadPreferences()
        current.notificationSettings = settings
        try await updatePreferences(current)
    }
    
    func updatePrivacySettings(_ settings: PrivacyPreferences) async throws {
        var current = await loadPreferences()
        current.privacySettings = settings
        try await updatePreferences(current)
    }
    
    func updateDisplaySettings(_ settings: DisplayPreferences) async throws {
        var current = await loadPreferences()
        current.displaySettings = settings
        try await updatePreferences(current)
    }
}

// MARK: - Errors

enum PreferencesError: LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to save preferences: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to load preferences: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Service

class MockUserPreferencesService: UserPreferencesServiceProtocol {
    private let preferencesSubject = CurrentValueSubject<UserPreferences, Never>(UserPreferences())
    
    var preferences: AnyPublisher<UserPreferences, Never> {
        preferencesSubject.eraseToAnyPublisher()
    }
    
    func loadPreferences() async -> UserPreferences {
        return preferencesSubject.value
    }
    
    func updatePreferences(_ preferences: UserPreferences) async throws {
        preferencesSubject.send(preferences)
    }
    
    func updateNotificationSettings(_ settings: NotificationPreferences) async throws {
        var current = preferencesSubject.value
        current.notificationSettings = settings
        preferencesSubject.send(current)
    }
    
    func updatePrivacySettings(_ settings: PrivacyPreferences) async throws {
        var current = preferencesSubject.value
        current.privacySettings = settings
        preferencesSubject.send(current)
    }
    
    func updateDisplaySettings(_ settings: DisplayPreferences) async throws {
        var current = preferencesSubject.value
        current.displaySettings = settings
        preferencesSubject.send(current)
    }
}

