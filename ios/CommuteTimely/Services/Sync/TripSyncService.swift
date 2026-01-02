//
// TripSyncService.swift
// CommuteTimely
//
// Service for syncing trips between local storage and Supabase cloud
//

import Foundation
import Supabase
import Combine

protocol TripSyncServiceProtocol {
    func syncToCloud(_ trip: Trip) async throws
    func deleteFromCloud(_ tripId: UUID) async throws
    func fetchFromCloud() async throws -> [Trip]
    func syncAllToCloud(_ trips: [Trip]) async throws
}

@MainActor
final class TripSyncService: TripSyncServiceProtocol {
    private let client: SupabaseClient
    
    init(client: SupabaseClient? = nil) {
        self.client = client ?? SupabaseService.shared.client
    }
    
    // MARK: - Sync Single Trip to Cloud
    
    func syncToCloud(_ trip: Trip) async throws {
        // Check if user is authenticated
        guard let session = try? await client.auth.session else {
            print("[TripSync] No authenticated user, skipping cloud sync")
            return
        }
        
        let userId = session.user.id
        let payload = SupabaseTripPayload(trip: trip, userId: userId)
        
        try await client
            .from("trips")
            .upsert(payload, onConflict: "id")
            .execute()
        
        print("[TripSync] Synced trip \(trip.id) to cloud")
    }
    
    // MARK: - Delete From Cloud
    
    func deleteFromCloud(_ tripId: UUID) async throws {
        guard let session = try? await client.auth.session else {
            return
        }
        
        try await client
            .from("trips")
            .delete()
            .eq("id", value: tripId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        print("[TripSync] Deleted trip \(tripId) from cloud")
    }
    
    // MARK: - Fetch All Trips From Cloud
    
    func fetchFromCloud() async throws -> [Trip] {
        guard let session = try? await client.auth.session else {
            return []
        }
        
        let response: [SupabaseTripPayload] = try await client
            .from("trips")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
            .value
        
        let trips = response.compactMap { $0.toTrip() }
        print("[TripSync] Fetched \(trips.count) trips from cloud")
        return trips
    }
    
    // MARK: - Sync All Trips to Cloud
    
    func syncAllToCloud(_ trips: [Trip]) async throws {
        guard let session = try? await client.auth.session else {
            return
        }
        
        let userId = session.user.id
        let payloads = trips.map { SupabaseTripPayload(trip: $0, userId: userId) }
        
        try await client
            .from("trips")
            .upsert(payloads, onConflict: "id")
            .execute()
        
        print("[TripSync] Synced \(trips.count) trips to cloud")
    }
}

// MARK: - Supabase Trip Payload

private struct SupabaseTripPayload: Codable {
    let id: UUID
    let userId: UUID
    let destinationAddress: String
    let destinationLatitude: Double
    let destinationLongitude: Double
    let destinationDisplayName: String
    let destinationPlaceName: String?
    let arrivalTime: Date
    let bufferMinutes: Int
    let repeatDays: [Int]
    let isActive: Bool
    let customName: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case destinationAddress = "destination_address"
        case destinationLatitude = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case destinationDisplayName = "destination_display_name"
        case destinationPlaceName = "destination_place_name"
        case arrivalTime = "arrival_time"
        case bufferMinutes = "buffer_minutes"
        case repeatDays = "repeat_days"
        case isActive = "is_active"
        case customName = "custom_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(trip: Trip, userId: UUID) {
        self.id = trip.id
        self.userId = userId
        self.destinationAddress = trip.destination.address
        self.destinationLatitude = trip.destination.coordinate.latitude
        self.destinationLongitude = trip.destination.coordinate.longitude
        self.destinationDisplayName = trip.destination.displayName
        self.destinationPlaceName = trip.destination.placeName
        self.arrivalTime = trip.arrivalTime
        self.bufferMinutes = trip.bufferMinutes
        self.repeatDays = trip.repeatDays.map { $0.rawValue }
        self.isActive = trip.isActive
        self.customName = trip.customName
        self.createdAt = trip.createdAt
        self.updatedAt = trip.updatedAt
    }
    
    func toTrip() -> Trip? {
        // Location uses placeName for display, not a separate displayName parameter
        let destination = Location(
            coordinate: Coordinate(latitude: destinationLatitude, longitude: destinationLongitude),
            address: destinationAddress,
            placeName: destinationPlaceName ?? destinationDisplayName
        )
        
        let weekdays = repeatDays.compactMap { WeekDay(rawValue: $0) }
        
        return Trip(
            id: id,
            destination: destination,
            arrivalTime: arrivalTime,
            bufferMinutes: bufferMinutes,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            repeatDays: Set(weekdays),
            customName: customName
        )
    }
}

// MARK: - Mock Service

class MockTripSyncService: TripSyncServiceProtocol {
    var syncedTrips: [Trip] = []
    
    func syncToCloud(_ trip: Trip) async throws {
        syncedTrips.removeAll { $0.id == trip.id }
        syncedTrips.append(trip)
    }
    
    func deleteFromCloud(_ tripId: UUID) async throws {
        syncedTrips.removeAll { $0.id == tripId }
    }
    
    func fetchFromCloud() async throws -> [Trip] {
        return syncedTrips
    }
    
    func syncAllToCloud(_ trips: [Trip]) async throws {
        syncedTrips = trips
    }
}
