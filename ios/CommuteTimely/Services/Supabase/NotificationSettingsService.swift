//
// NotificationSettingsService.swift
// CommuteTimely
//
// Supabase notification_settings table service
//

import Foundation
import Supabase
import OSLog

@MainActor
final class NotificationSettingsService: NotificationSettingsServiceProtocol {
    private let client: SupabaseClient
    private var _cachedSettings: NotificationSettingsRecord?
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "NotificationSettingsService")
    
    var cachedSettings: NotificationSettingsRecord? {
        _cachedSettings
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func getSettings() async throws -> NotificationSettingsRecord {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            let response: [NotificationSettingsRecord] = try await client
                .from("notification_settings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            if let settings = response.first {
                _cachedSettings = settings
                return settings
            }
            
            // Create default settings if none exist
            let defaults = NotificationSettingsRecord(
                id: UUID(),
                userId: userId,
                enableNotifications: true,
                advanceMinutes: 30,
                dailyReminderTime: nil,
                soundEnabled: true,
                vibrationEnabled: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            let created: [NotificationSettingsRecord] = try await client
                .from("notification_settings")
                .insert(defaults)
                .select()
                .execute()
                .value
            
            guard let savedSettings = created.first else {
                throw SupabaseError.invalidResponse
            }
            
            _cachedSettings = savedSettings
            return savedSettings
        } catch {
            Self.logger.error("Failed to get notification settings: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func upsertSettings(_ settings: NotificationSettingsRecord) async throws -> NotificationSettingsRecord {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            var updatedSettings = settings
            updatedSettings.userId = userId
            updatedSettings.updatedAt = Date()
            
            let response: [NotificationSettingsRecord] = try await client
                .from("notification_settings")
                .upsert(updatedSettings)
                .select()
                .execute()
                .value
            
            guard let savedSettings = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            _cachedSettings = savedSettings
            return savedSettings
        } catch {
            Self.logger.error("Failed to upsert notification settings: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func observeSettings() -> AsyncStream<NotificationSettingsRecord> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    let settings = try await getSettings()
                    continuation.yield(settings)
                } catch {
                    if let cached = _cachedSettings {
                        continuation.yield(cached)
                    }
                }
                
                // Note: Supabase Realtime would go here if enabled
                continuation.finish()
            }
        }
    }
}
