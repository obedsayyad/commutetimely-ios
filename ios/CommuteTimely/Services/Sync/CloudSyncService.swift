//
// CloudSyncService.swift
// CommuteTimely
//
// Cloud synchronization service for trips and preferences
//

import Foundation
import Combine

protocol CloudSyncServiceProtocol {
    var isSyncing: AnyPublisher<Bool, Never> { get }
    var lastSyncDate: AnyPublisher<Date?, Never> { get }
    
    func syncTrips(_ trips: [Trip]) async throws
    func fetchTrips() async throws -> [Trip]
    func deleteTrip(_ tripId: String) async throws
    func syncPreferences(_ preferences: UserPreferences) async throws
    func fetchPreferences() async throws -> UserPreferences?
    func enableAutoSync(_ enabled: Bool)
}

class CloudSyncService: CloudSyncServiceProtocol {
    private let baseURL: String
    private let networkService: NetworkServiceProtocol
    private let authTokenProvider: () async throws -> String?
    
    @Published private var _isSyncing: Bool = false
    @Published private var _lastSyncDate: Date?
    
    private var autoSyncEnabled: Bool = true
    private var cancellables = Set<AnyCancellable>()
    
    var isSyncing: AnyPublisher<Bool, Never> {
        $_isSyncing.eraseToAnyPublisher()
    }
    
    var lastSyncDate: AnyPublisher<Date?, Never> {
        $_lastSyncDate.eraseToAnyPublisher()
    }
    
    init(
        baseURL: String,
        networkService: NetworkServiceProtocol,
        authTokenProvider: @escaping () async throws -> String?
    ) {
        self.baseURL = baseURL
        self.networkService = networkService
        self.authTokenProvider = authTokenProvider
    }
    
    // MARK: - Trips Sync
    
    func syncTrips(_ trips: [Trip]) async throws {
        guard autoSyncEnabled else { return }
        guard let token = try await authTokenProvider() else {
            // User not authenticated, skip sync
            return
        }
        
        _isSyncing = true
        defer { _isSyncing = false }
        
        guard let url = URL(string: "\(baseURL)/sync/trips") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload = RemoteTripsEnvelope(trips: trips.map { RemoteTripPayload(trip: $0) })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
        
        _lastSyncDate = Date()
    }
    
    func fetchTrips() async throws -> [Trip] {
        guard let token = try await authTokenProvider() else {
            // User not authenticated, return empty
            return []
        }
        
        _isSyncing = true
        defer { _isSyncing = false }
        
        guard let url = URL(string: "\(baseURL)/sync/trips") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(RemoteTripsEnvelope.self, from: data)
        let trips = payload.trips.map { $0.makeTrip() }
        
        _lastSyncDate = Date()
        return trips
    }
    
    func deleteTrip(_ tripId: String) async throws {
        guard let token = try await authTokenProvider() else {
            return
        }
        
        guard let url = URL(string: "\(baseURL)/sync/trips/\(tripId)") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
    }
    
    // MARK: - Preferences Sync
    
    func syncPreferences(_ preferences: UserPreferences) async throws {
        guard autoSyncEnabled else { return }
        guard let token = try await authTokenProvider() else {
            return
        }
        
        _isSyncing = true
        defer { _isSyncing = false }
        
        guard let url = URL(string: "\(baseURL)/sync/preferences") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        let preferencesData = try encoder.encode(preferences)
        let preferencesDict = try JSONSerialization.jsonObject(with: preferencesData) as? [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["preferences": preferencesDict as Any])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
        
        _lastSyncDate = Date()
    }
    
    func fetchPreferences() async throws -> UserPreferences? {
        guard let token = try await authTokenProvider() else {
            return nil
        }
        
        _isSyncing = true
        defer { _isSyncing = false }
        
        guard let url = URL(string: "\(baseURL)/sync/preferences") else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let preferencesDict = json?["preferences"] as? [String: Any],
              !preferencesDict.isEmpty else {
            return nil
        }
        
        let preferencesData = try JSONSerialization.data(withJSONObject: preferencesDict)
        let decoder = JSONDecoder()
        let preferences = try decoder.decode(UserPreferences.self, from: preferencesData)
        
        _lastSyncDate = Date()
        return preferences
    }
    
    // MARK: - Configuration
    
    func enableAutoSync(_ enabled: Bool) {
        autoSyncEnabled = enabled
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case invalidURL
    case serverError
    case notAuthenticated
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid sync URL"
        case .serverError:
            return "Server error during sync"
        case .notAuthenticated:
            return "Authentication required for sync"
        case .encodingError:
            return "Failed to encode data for sync"
        case .decodingError:
            return "Failed to decode synced data"
        }
    }
}

// MARK: - Remote DTOs

private extension CloudSyncService {
    struct RemoteTripsEnvelope: Codable {
        let trips: [RemoteTripPayload]
    }
    
    struct RemoteTripPayload: Codable {
        let id: UUID
        let destinationAddress: String
        let destinationPlaceName: String?
        let destinationLatitude: Double
        let destinationLongitude: Double
        let destinationPlaceType: String?
        let arrivalTime: Date
        let bufferMinutes: Int
        let isActive: Bool
        let createdAt: Date?
        let updatedAt: Date?
        let repeatDays: [Int]?
        let notificationSettings: RemoteNotificationSettings?
        let customName: String?
        let notes: String?
        let transportMode: String?
        let tags: [String]?
        let lastRouteSnapshot: RouteSnapshot?
        let expectedWeatherSummary: String?
        let arrivalBufferMinutes: Int?
        
        init(trip: Trip) {
            self.id = trip.id
            let destination = trip.destination
            self.destinationAddress = destination.address
            self.destinationPlaceName = destination.placeName
            self.destinationLatitude = destination.coordinate.latitude
            self.destinationLongitude = destination.coordinate.longitude
            self.destinationPlaceType = destination.placeType?.rawValue
            self.arrivalTime = trip.arrivalTime
            self.bufferMinutes = trip.bufferMinutes
            self.isActive = trip.isActive
            self.createdAt = trip.createdAt
            self.updatedAt = trip.updatedAt
            let repeatDayValues = trip.repeatDays.map { $0.rawValue }.sorted()
            self.repeatDays = repeatDayValues.isEmpty ? nil : repeatDayValues
            self.notificationSettings = RemoteNotificationSettings(settings: trip.notificationSettings)
            self.customName = trip.customName
            self.notes = trip.notes
            self.transportMode = trip.transportMode.rawValue
            self.tags = trip.tags.map { $0.rawValue }
            self.lastRouteSnapshot = trip.lastRouteSnapshot
            self.expectedWeatherSummary = trip.expectedWeatherSummary
            self.arrivalBufferMinutes = trip.arrivalBufferMinutes
        }
        
        func makeTrip() -> Trip {
            Trip(
                id: id,
                destination: Location(
                    coordinate: Coordinate(latitude: destinationLatitude, longitude: destinationLongitude),
                    address: destinationAddress,
                    placeName: destinationPlaceName,
                    placeType: destinationPlaceType.flatMap { PlaceType(rawValue: $0) }
                ),
                arrivalTime: arrivalTime,
                bufferMinutes: bufferMinutes,
                isActive: isActive,
                createdAt: createdAt ?? Date(),
                updatedAt: updatedAt ?? Date(),
                repeatDays: Set((repeatDays ?? []).compactMap { WeekDay(rawValue: $0) }),
                notificationSettings: notificationSettings?.makeSettings() ?? TripNotificationSettings(),
                customName: customName,
                notes: notes,
                transportMode: transportMode.flatMap { TransportMode(rawValue: $0) } ?? .driving,
                tags: Set((tags ?? []).compactMap { DestinationTag(rawValue: $0) }),
                lastRouteSnapshot: lastRouteSnapshot,
                expectedWeatherSummary: expectedWeatherSummary,
                arrivalBufferMinutes: arrivalBufferMinutes ?? 0
            )
        }
    }
    
    struct RemoteNotificationSettings: Codable {
        let enableMainNotification: Bool
        let enableReminderNotifications: Bool
        let reminderOffsets: [Int]
        let soundEnabled: Bool
        let vibrationEnabled: Bool
        
        init(settings: TripNotificationSettings) {
            self.enableMainNotification = settings.enableMainNotification
            self.enableReminderNotifications = settings.enableReminderNotifications
            self.reminderOffsets = settings.reminderOffsets
            self.soundEnabled = settings.soundEnabled
            self.vibrationEnabled = settings.vibrationEnabled
        }
        
        func makeSettings() -> TripNotificationSettings {
            TripNotificationSettings(
                enableMainNotification: enableMainNotification,
                enableReminderNotifications: enableReminderNotifications,
                reminderOffsets: reminderOffsets,
                soundEnabled: soundEnabled,
                vibrationEnabled: vibrationEnabled
            )
        }
    }
}

// MARK: - Mock Service

class MockCloudSyncService: CloudSyncServiceProtocol {
    @Published private var _isSyncing: Bool = false
    @Published private var _lastSyncDate: Date?
    
    var isSyncing: AnyPublisher<Bool, Never> {
        $_isSyncing.eraseToAnyPublisher()
    }
    
    var lastSyncDate: AnyPublisher<Date?, Never> {
        $_lastSyncDate.eraseToAnyPublisher()
    }
    
    private var mockTrips: [Trip] = []
    private var mockPreferences: UserPreferences?
    
    init() {}
    
    func syncTrips(_ trips: [Trip]) async throws {
        mockTrips = trips
        _lastSyncDate = Date()
    }
    
    func fetchTrips() async throws -> [Trip] {
        return mockTrips
    }
    
    func deleteTrip(_ tripId: String) async throws {
        mockTrips.removeAll { $0.id.uuidString == tripId }
    }
    
    func syncPreferences(_ preferences: UserPreferences) async throws {
        mockPreferences = preferences
        _lastSyncDate = Date()
    }
    
    func fetchPreferences() async throws -> UserPreferences? {
        return mockPreferences
    }
    
    func enableAutoSync(_ enabled: Bool) {}
}

