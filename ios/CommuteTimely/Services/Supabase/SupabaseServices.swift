//
// SupabaseServices.swift
// CommuteTimely
//
// Core Supabase-backed service protocols and lightweight model stubs.
// Concrete implementations will be filled in by subsequent tasks.
//

import Foundation
import Supabase

// MARK: - Shared Models (lightweight stubs; extended later as needed)

struct UserProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var name: String?
    var email: String?
    var avatarURL: URL?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case email
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID, userId: UUID, name: String? = nil, email: String? = nil, avatarURL: URL? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        // These fields may not exist in the database - decode gracefully
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        // Only encode timestamps if they exist
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct DestinationRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var title: String
    var address: String
    var latitude: Double
    var longitude: Double
    var isHome: Bool
    var isWork: Bool
    var createdAt: Date?
    var updatedAt: Date?
}

struct TripPlan: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var destinationId: UUID
    var plannedArrival: Date
    var predictedLeaveTime: Date?
    var routeSnapshotJSON: String?
    var weatherSummary: String?
    var modelVersion: String?
    var status: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct NotificationSettingsRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var enableNotifications: Bool
    var advanceMinutes: Int
    var dailyReminderTime: Date?
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var createdAt: Date?
    var updatedAt: Date?
}

struct PredictionLog: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var destinationId: UUID?
    var tripPlanId: UUID?
    var trafficLevel: String?
    var weatherSummary: String?
    var predictedLeaveTime: Date?
    var modelVersion: String?
    var createdAt: Date?
}

// MARK: - Service Protocols

protocol SupabaseAuthServiceProtocol: AnyObject {
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func sendMagicLink(email: String) async throws
    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle(idToken: String) async throws
    func signOut() async throws
    func restoreSessionFromKeychain() async throws
}

protocol UserProfileServiceProtocol: AnyObject {
    @MainActor
    var cachedProfile: UserProfile? { get }

    func fetchCurrentUserProfile() async throws -> UserProfile
    func upsertProfile(_ profile: UserProfile) async throws -> UserProfile
    func deleteProfile() async throws
}

protocol DestinationServiceProtocol: AnyObject {
    @MainActor
    var cachedDestinations: [DestinationRecord] { get }

    func listDestinations() async throws -> [DestinationRecord]
    func addDestination(_ record: DestinationRecord) async throws -> DestinationRecord
    func updateDestination(_ record: DestinationRecord) async throws -> DestinationRecord
    func deleteDestination(id: UUID) async throws
    func observeDestinations() -> AsyncStream<[DestinationRecord]>
}

struct NewTripPlanRequest {
    let destinationId: UUID
    let plannedArrival: Date
    let predictedLeaveTime: Date?
    let routeSnapshotJSON: String?
    let weatherSummary: String?
    let modelVersion: String?
}

protocol TripPlanServiceProtocol: AnyObject {
    @MainActor
    var cachedTodayPlans: [TripPlan] { get }

    func createTripPlan(request: NewTripPlanRequest) async throws -> TripPlan
    func getTripPlansForToday() async throws -> [TripPlan]
    func getTripPlans(forDestination destinationId: UUID) async throws -> [TripPlan]
    func updateTripPlan(_ plan: TripPlan) async throws -> TripPlan
    func deleteOldTripPlans(before date: Date) async throws
}

protocol NotificationSettingsServiceProtocol: AnyObject {
    @MainActor
    var cachedSettings: NotificationSettingsRecord? { get }

    func getSettings() async throws -> NotificationSettingsRecord
    func upsertSettings(_ settings: NotificationSettingsRecord) async throws -> NotificationSettingsRecord
    func observeSettings() -> AsyncStream<NotificationSettingsRecord>
}

protocol PredictionLogServiceProtocol: AnyObject {
    func logPrediction(_ log: PredictionLog) async
}

// MARK: - Default No-Op Implementations

/// Lightweight placeholder implementations so we can wire DI early.
/// These will be replaced with real implementations in later tasks.

final class NoopSupabaseAuthService: SupabaseAuthServiceProtocol {
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func sendMagicLink(email: String) async throws {}
    func signInWithApple(idToken: String, nonce: String) async throws {}
    func signInWithGoogle(idToken: String) async throws {}
    func signOut() async throws {}
    func restoreSessionFromKeychain() async throws {}
}

@MainActor
final class NoopUserProfileService: UserProfileServiceProtocol {
    private(set) var cachedProfile: UserProfile?

    func fetchCurrentUserProfile() async throws -> UserProfile {
        throw SupabaseError.notFound
    }

    func upsertProfile(_ profile: UserProfile) async throws -> UserProfile {
        cachedProfile = profile
        return profile
    }

    func deleteProfile() async throws {
        cachedProfile = nil
    }
}

@MainActor
final class NoopDestinationService: DestinationServiceProtocol {
    private(set) var cachedDestinations: [DestinationRecord] = []

    func listDestinations() async throws -> [DestinationRecord] {
        return cachedDestinations
    }

    func addDestination(_ record: DestinationRecord) async throws -> DestinationRecord {
        cachedDestinations.append(record)
        return record
    }

    func updateDestination(_ record: DestinationRecord) async throws -> DestinationRecord {
        if let index = cachedDestinations.firstIndex(where: { $0.id == record.id }) {
            cachedDestinations[index] = record
        }
        return record
    }

    func deleteDestination(id: UUID) async throws {
        cachedDestinations.removeAll { $0.id == id }
    }

    func observeDestinations() -> AsyncStream<[DestinationRecord]> {
        AsyncStream { continuation in
            continuation.yield(cachedDestinations)
            continuation.finish()
        }
    }
}

@MainActor
final class NoopTripPlanService: TripPlanServiceProtocol {
    private(set) var cachedTodayPlans: [TripPlan] = []

    func createTripPlan(request: NewTripPlanRequest) async throws -> TripPlan {
        let plan = TripPlan(
            id: UUID(),
            userId: UUID(),
            destinationId: request.destinationId,
            plannedArrival: request.plannedArrival,
            predictedLeaveTime: request.predictedLeaveTime,
            routeSnapshotJSON: request.routeSnapshotJSON,
            weatherSummary: request.weatherSummary,
            modelVersion: request.modelVersion,
            status: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedTodayPlans.append(plan)
        return plan
    }

    func getTripPlansForToday() async throws -> [TripPlan] {
        return cachedTodayPlans
    }

    func getTripPlans(forDestination destinationId: UUID) async throws -> [TripPlan] {
        return cachedTodayPlans.filter { $0.destinationId == destinationId }
    }

    func updateTripPlan(_ plan: TripPlan) async throws -> TripPlan {
        if let index = cachedTodayPlans.firstIndex(where: { $0.id == plan.id }) {
            cachedTodayPlans[index] = plan
        }
        return plan
    }

    func deleteOldTripPlans(before date: Date) async throws {
        cachedTodayPlans.removeAll { ($0.createdAt ?? Date()) < date }
    }
}

@MainActor
final class NoopNotificationSettingsService: NotificationSettingsServiceProtocol {
    private(set) var cachedSettings: NotificationSettingsRecord?

    func getSettings() async throws -> NotificationSettingsRecord {
        if let cachedSettings {
            return cachedSettings
        }
        let defaults = NotificationSettingsRecord(
            id: UUID(),
            userId: UUID(),
            enableNotifications: true,
            advanceMinutes: 30,
            dailyReminderTime: nil,
            soundEnabled: true,
            vibrationEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        cachedSettings = defaults
        return defaults
    }

    func upsertSettings(_ settings: NotificationSettingsRecord) async throws -> NotificationSettingsRecord {
        cachedSettings = settings
        return settings
    }

    func observeSettings() -> AsyncStream<NotificationSettingsRecord> {
        AsyncStream { continuation in
            if let cachedSettings {
                continuation.yield(cachedSettings)
            }
            continuation.finish()
        }
    }
}

final class NoopPredictionLogService: PredictionLogServiceProtocol {
    func logPrediction(_ log: PredictionLog) async {
        // Intentionally no-op; used in development and tests
    }
}


