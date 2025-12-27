//
// TripStorageService.swift
// CommuteTimely
//
// Service for persisting and managing trips
//

import Foundation
import Combine

protocol TripStorageServiceProtocol {
    var trips: AnyPublisher<[Trip], Never> { get }
    
    func fetchTrips() async -> [Trip]
    func fetchTrip(id: UUID) async -> Trip?
    func saveTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
    func deleteAllTrips() async throws
    func exportTrips() async throws -> Data
    func importTrips(from data: Data) async throws
    func canCreateTrip(isSubscribed: Bool, subscriptionTier: SubscriptionTier) async -> Bool
    func getTripsCreatedToday() async -> Int
}

extension TripStorageServiceProtocol {
    func exportTrips() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let trips = await fetchTrips()
        return try encoder.encode(trips)
    }
    
    func importTrips(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let trips = try decoder.decode([Trip].self, from: data)
        try await deleteAllTrips()
        for trip in trips {
            try await saveTrip(trip)
        }
    }
}

class TripStorageService: TripStorageServiceProtocol {
    private let tripsSubject = CurrentValueSubject<[Trip], Never>([])
    private let store: DestinationStoreProtocol
    
    // App Group identifier for widget sharing
    private let appGroupIdentifier = "group.com.commutetimely.shared"
    
    var trips: AnyPublisher<[Trip], Never> {
        tripsSubject.eraseToAnyPublisher()
    }
    
    init(store: DestinationStoreProtocol = CoreDataDestinationStore()) {
        self.store = store
        Task {
            await self.reloadTrips()
        }
    }
    
    func fetchTrips() async -> [Trip] {
        do {
            let trips = try await store.fetchTrips()
            return trips.sorted { $0.arrivalTime < $1.arrivalTime }
        } catch {
            print("[TripStorage] Failed to fetch trips: \(error)")
            return []
        }
    }
    
    func fetchTrip(id: UUID) async -> Trip? {
        let allTrips = await fetchTrips()
        return allTrips.first { $0.id == id }
    }
    
    func saveTrip(_ trip: Trip) async throws {
        try await store.saveTrip(trip)
        await reloadTrips()
        // Increment daily trip count
        await incrementDailyTripCount()
    }
    
    func updateTrip(_ trip: Trip) async throws {
        var updated = trip
        updated.updatedAt = Date()
        try await store.updateTrip(updated)
        await reloadTrips()
    }
    
    func deleteTrip(id: UUID) async throws {
        try await store.deleteTrip(id: id)
        await reloadTrips()
    }
    
    func deleteAllTrips() async throws {
        try await store.deleteAll()
        await reloadTrips()
    }
    
    func exportTrips() async throws -> Data {
        try await store.exportTrips()
    }
    
    func importTrips(from data: Data) async throws {
        try await store.importTrips(from: data)
        await reloadTrips()
    }
    
    func canCreateTrip(isSubscribed: Bool, subscriptionTier: SubscriptionTier) async -> Bool {
        // Premium users can create unlimited trips
        if isSubscribed {
            return true
        }
        
        // Free tier: check daily limit (3 trips per day)
        let tripsCreatedToday = await getTripsCreatedToday()
        return tripsCreatedToday < subscriptionTier.maxTrips
    }
    
    func getTripsCreatedToday() async -> Int {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = "trips_created_\(dateFormatter.string(from: today))"
        
        // Check if we have a count for today
        let lastDateKey = "last_trip_date"
        let lastDateString = UserDefaults.standard.string(forKey: lastDateKey)
        let todayString = dateFormatter.string(from: today)
        
        // If last date is not today, reset count
        if lastDateString != todayString {
            UserDefaults.standard.removeObject(forKey: todayKey)
            return 0
        }
        
        return UserDefaults.standard.integer(forKey: todayKey)
    }
    
    // MARK: - Private
    
    private func reloadTrips() async {
        let current = await fetchTrips()
        await MainActor.run {
            self.tripsSubject.send(current)
        }
        // Sync to App Group for widget access
        await syncTripsToAppGroup(trips: current)
    }
    
    private func syncTripsToAppGroup(trips: [Trip]) async {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("[TripStorage] Failed to access App Group UserDefaults")
            return
        }
        
        // Convert trips to simplified format for widget
        let widgetTrips = trips.map { trip in
            WidgetTripData(
                id: trip.id,
                destinationName: trip.customName ?? trip.destination.displayName,
                arrivalTime: trip.arrivalTime,
                bufferMinutes: trip.bufferMinutes,
                isActive: trip.isActive,
                travelTimeMinutes: trip.cachedTravelTimeMinutes
            )
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(widgetTrips)
            sharedDefaults.set(data, forKey: "sharedTrips")
            sharedDefaults.synchronize()
        } catch {
            print("[TripStorage] Failed to encode trips for widget: \(error)")
        }
    }
    
    private func incrementDailyTripCount() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let todayString = dateFormatter.string(from: today)
        let todayKey = "trips_created_\(todayString)"
        let lastDateKey = "last_trip_date"
        
        // Check if we need to reset (new day)
        let lastDateString = UserDefaults.standard.string(forKey: lastDateKey)
        if lastDateString != todayString {
            UserDefaults.standard.removeObject(forKey: todayKey)
        }
        
        // Increment count
        let currentCount = UserDefaults.standard.integer(forKey: todayKey)
        UserDefaults.standard.set(currentCount + 1, forKey: todayKey)
        UserDefaults.standard.set(todayString, forKey: lastDateKey)
    }
}

// MARK: - Widget Data Structure

private struct WidgetTripData: Codable {
    let id: UUID
    let destinationName: String
    let arrivalTime: Date
    let bufferMinutes: Int
    let isActive: Bool
    let travelTimeMinutes: Int?
}

// MARK: - Errors

enum TripStorageError: LocalizedError {
    case tripNotFound
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .tripNotFound:
            return "Trip not found"
        case .encodingFailed(let error):
            return "Failed to save trip: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to load trip: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Service

class MockTripStorageService: TripStorageServiceProtocol {
    private let tripsSubject = CurrentValueSubject<[Trip], Never>([])
    
    var trips: AnyPublisher<[Trip], Never> {
        tripsSubject.eraseToAnyPublisher()
    }
    
    func fetchTrips() async -> [Trip] {
        return tripsSubject.value
    }
    
    func fetchTrip(id: UUID) async -> Trip? {
        return tripsSubject.value.first { $0.id == id }
    }
    
    func saveTrip(_ trip: Trip) async throws {
        var currentTrips = tripsSubject.value
        currentTrips.append(trip)
        tripsSubject.send(currentTrips)
    }
    
    func updateTrip(_ trip: Trip) async throws {
        var currentTrips = tripsSubject.value
        if let index = currentTrips.firstIndex(where: { $0.id == trip.id }) {
            currentTrips[index] = trip
            tripsSubject.send(currentTrips)
        }
    }
    
    func deleteTrip(id: UUID) async throws {
        var currentTrips = tripsSubject.value
        currentTrips.removeAll { $0.id == id }
        tripsSubject.send(currentTrips)
    }
    
    func deleteAllTrips() async throws {
        tripsSubject.send([])
    }
    
    func canCreateTrip(isSubscribed: Bool, subscriptionTier: SubscriptionTier) async -> Bool {
        // Premium users can create unlimited trips
        if isSubscribed {
            return true
        }
        
        // Free tier: check daily limit (3 trips per day)
        let tripsCreatedToday = await getTripsCreatedToday()
        return tripsCreatedToday < subscriptionTier.maxTrips
    }
    
    func getTripsCreatedToday() async -> Int {
        // Mock: Always return 0 for testing
        return 0
    }
}

