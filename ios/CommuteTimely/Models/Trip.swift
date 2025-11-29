//
// Trip.swift
// CommuteTimely
//
// Core trip model representing a saved destination with arrival time
//

import Foundation
import CoreLocation

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var destination: Location
    var arrivalTime: Date
    var bufferMinutes: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var repeatDays: Set<WeekDay>
    var notificationSettings: TripNotificationSettings
    var customName: String?
    var notes: String?
    var transportMode: TransportMode
    var tags: Set<DestinationTag>
    var lastRouteSnapshot: RouteSnapshot?
    var expectedWeatherSummary: String?
    var arrivalBufferMinutes: Int
    
    init(
        id: UUID = UUID(),
        destination: Location,
        arrivalTime: Date,
        bufferMinutes: Int = 10,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        repeatDays: Set<WeekDay> = [],
        notificationSettings: TripNotificationSettings = TripNotificationSettings(),
        customName: String? = nil,
        notes: String? = nil,
        transportMode: TransportMode = .driving,
        tags: Set<DestinationTag> = [],
        lastRouteSnapshot: RouteSnapshot? = nil,
        expectedWeatherSummary: String? = nil,
        arrivalBufferMinutes: Int = 0
    ) {
        self.id = id
        self.destination = destination
        self.arrivalTime = arrivalTime
        self.bufferMinutes = bufferMinutes
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.repeatDays = repeatDays
        self.notificationSettings = notificationSettings
        self.customName = customName
        self.notes = notes
        self.transportMode = transportMode
        self.tags = tags
        self.lastRouteSnapshot = lastRouteSnapshot
        self.expectedWeatherSummary = expectedWeatherSummary
        self.arrivalBufferMinutes = arrivalBufferMinutes
    }
    
    var shouldTriggerToday: Bool {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        
        if repeatDays.isEmpty {
            // One-time trip: check if it's today
            return calendar.isDateInToday(arrivalTime)
        } else {
            // Recurring trip: check if today is in repeat days
            guard let weekDay = WeekDay(rawValue: today) else { return false }
            return repeatDays.contains(weekDay)
        }
    }
    
    var cachedTravelTimeMinutes: Int? {
        lastRouteSnapshot?.travelTimeMinutes
    }
    
    var cachedTrafficSummary: String? {
        lastRouteSnapshot?.trafficSummary
    }
    
    var typicalTrafficWindowDescription: String? {
        lastRouteSnapshot?.freshnessDescription
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case destination
        case arrivalTime
        case bufferMinutes
        case isActive
        case createdAt
        case updatedAt
        case repeatDays
        case notificationSettings
        case customName
        case notes
        case transportMode
        case tags
        case lastRouteSnapshot
        case expectedWeatherSummary
        case arrivalBufferMinutes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        destination = try container.decode(Location.self, forKey: .destination)
        arrivalTime = try container.decode(Date.self, forKey: .arrivalTime)
        bufferMinutes = try container.decodeIfPresent(Int.self, forKey: .bufferMinutes) ?? 10
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        if let repeatValues = try container.decodeIfPresent([WeekDay].self, forKey: .repeatDays) {
            repeatDays = Set(repeatValues)
        } else {
            repeatDays = []
        }
        notificationSettings = try container.decodeIfPresent(TripNotificationSettings.self, forKey: .notificationSettings) ?? TripNotificationSettings()
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        transportMode = try container.decodeIfPresent(TransportMode.self, forKey: .transportMode) ?? .driving
        if let decodedTags = try container.decodeIfPresent(Set<DestinationTag>.self, forKey: .tags) {
            tags = decodedTags
        } else {
            tags = []
        }
        lastRouteSnapshot = try container.decodeIfPresent(RouteSnapshot.self, forKey: .lastRouteSnapshot)
        expectedWeatherSummary = try container.decodeIfPresent(String.self, forKey: .expectedWeatherSummary)
        arrivalBufferMinutes = try container.decodeIfPresent(Int.self, forKey: .arrivalBufferMinutes) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(destination, forKey: .destination)
        try container.encode(arrivalTime, forKey: .arrivalTime)
        try container.encode(bufferMinutes, forKey: .bufferMinutes)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(Array(repeatDays), forKey: .repeatDays)
        try container.encode(notificationSettings, forKey: .notificationSettings)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(transportMode, forKey: .transportMode)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(lastRouteSnapshot, forKey: .lastRouteSnapshot)
        try container.encodeIfPresent(expectedWeatherSummary, forKey: .expectedWeatherSummary)
        try container.encode(arrivalBufferMinutes, forKey: .arrivalBufferMinutes)
    }
}

// MARK: - Location Model

struct Location: Codable, Equatable, Hashable {
    let coordinate: Coordinate
    let address: String
    let placeName: String?
    let placeType: PlaceType?
    
    init(
        coordinate: Coordinate,
        address: String,
        placeName: String? = nil,
        placeType: PlaceType? = nil
    ) {
        self.coordinate = coordinate
        self.address = address
        self.placeName = placeName
        self.placeType = placeType
    }
    
    var displayName: String {
        placeName ?? address
    }
}

struct Coordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(clCoordinate: CLLocationCoordinate2D) {
        self.latitude = clCoordinate.latitude
        self.longitude = clCoordinate.longitude
    }
    
    func distance(to other: Coordinate) -> Double {
        let first = CLLocation(latitude: latitude, longitude: longitude)
        let second = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return first.distance(from: second)
    }
}

enum PlaceType: String, Codable {
    case home
    case work
    case school
    case gym
    case restaurant
    case shop
    case other
}

enum DestinationTag: String, Codable, CaseIterable, Hashable {
    case home
    case work
    case favorite
    case urgent
}

enum TransportMode: String, Codable, CaseIterable, Hashable {
    case driving
    case walking
    case transit
    case cycling
}

@preconcurrency
struct RouteSnapshot: Codable, Equatable {
    let travelTimeMinutes: Int
    let trafficSummary: String
    let congestionLevel: CongestionLevel
    let capturedAt: Date
    let distanceMeters: Double
    
    var freshnessDescription: String {
        let delta = Date().timeIntervalSince(capturedAt)
        if delta < 30 {
            return "updated just now"
        } else if delta < 60 {
            return "updated \(Int(delta))s ago"
        } else {
            return "updated \(Int(delta / 60))m ago"
        }
    }
}

// MARK: - Week Day

enum WeekDay: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

// MARK: - Notification Settings

@preconcurrency
struct TripNotificationSettings: Codable, Equatable {
    var enableMainNotification: Bool
    var enableReminderNotifications: Bool
    var reminderOffsets: [Int] // Minutes before leave time
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    
    init(
        enableMainNotification: Bool = true,
        enableReminderNotifications: Bool = true,
        reminderOffsets: [Int] = [15, 5],
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true
    ) {
        self.enableMainNotification = enableMainNotification
        self.enableReminderNotifications = enableReminderNotifications
        self.reminderOffsets = reminderOffsets
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
    }
}

