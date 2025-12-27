//
// UserPreferences.swift
// CommuteTimely
//
// User settings and preferences model
//

import Foundation

struct UserPreferences: Codable, Equatable {
    var userId: String
    var notificationSettings: NotificationPreferences
    var privacySettings: PrivacyPreferences
    var displaySettings: DisplayPreferences
    var subscriptionStatus: SubscriptionStatus
    
    init(
        userId: String = UUID().uuidString,
        notificationSettings: NotificationPreferences = NotificationPreferences(),
        privacySettings: PrivacyPreferences = PrivacyPreferences(),
        displaySettings: DisplayPreferences = DisplayPreferences(),
        subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    ) {
        self.userId = userId
        self.notificationSettings = notificationSettings
        self.privacySettings = privacySettings
        self.displaySettings = displaySettings
        self.subscriptionStatus = subscriptionStatus
    }
}

struct NotificationPreferences: Codable, Equatable {
    var enableNotifications: Bool
    var defaultReminderOffsets: [Int] // minutes before
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var criticalAlertsEnabled: Bool
    var personalizedDailyNotificationsEnabled: Bool
    var personalizedNotificationDayIndex: Int // 0-6, representing day 1-7
    var personalizedNotificationHour: Int // 0-23, default: 8
    var personalizedNotificationMinute: Int // 0-59, default: 0
    var dynamicIslandUpdatesEnabled: Bool
    
    init(
        enableNotifications: Bool = true,
        defaultReminderOffsets: [Int] = [15, 5],
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true,
        criticalAlertsEnabled: Bool = false,
        personalizedDailyNotificationsEnabled: Bool = false,
        personalizedNotificationDayIndex: Int = 0,
        personalizedNotificationHour: Int = 8,
        personalizedNotificationMinute: Int = 0,
        dynamicIslandUpdatesEnabled: Bool = true
    ) {
        self.enableNotifications = enableNotifications
        self.defaultReminderOffsets = defaultReminderOffsets
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.criticalAlertsEnabled = criticalAlertsEnabled
        self.personalizedDailyNotificationsEnabled = personalizedDailyNotificationsEnabled
        self.personalizedNotificationDayIndex = personalizedNotificationDayIndex
        self.personalizedNotificationHour = personalizedNotificationHour
        self.personalizedNotificationMinute = personalizedNotificationMinute
        self.dynamicIslandUpdatesEnabled = dynamicIslandUpdatesEnabled
    }
    
    var personalizedNotificationTime: DateComponents {
        DateComponents(hour: personalizedNotificationHour, minute: personalizedNotificationMinute)
    }
}

struct PrivacyPreferences: Codable, Equatable {
    var analyticsEnabled: Bool
    var dataSharingEnabled: Bool
    var locationTrackingEnabled: Bool
    var calendarAccessEnabled: Bool
    
    init(
        analyticsEnabled: Bool = false,
        dataSharingEnabled: Bool = false,
        locationTrackingEnabled: Bool = true,
        calendarAccessEnabled: Bool = false
    ) {
        self.analyticsEnabled = analyticsEnabled
        self.dataSharingEnabled = dataSharingEnabled
        self.locationTrackingEnabled = locationTrackingEnabled
        self.calendarAccessEnabled = calendarAccessEnabled
    }
}

struct DisplayPreferences: Codable, Equatable {
    var temperatureUnit: TemperatureUnit
    var distanceUnit: DistanceUnit
    var timeFormat: TimeFormat
    var mapStyle: MapStyle
    
    init(
        temperatureUnit: TemperatureUnit = .fahrenheit,
        distanceUnit: DistanceUnit = .miles,
        timeFormat: TimeFormat = .twelveHour,
        mapStyle: MapStyle = .standard
    ) {
        self.temperatureUnit = temperatureUnit
        self.distanceUnit = distanceUnit
        self.timeFormat = timeFormat
        self.mapStyle = mapStyle
    }
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit
    
    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case miles
    case kilometers
    
    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }
}

enum TimeFormat: String, Codable, CaseIterable {
    case twelveHour
    case twentyFourHour
    
    var displayName: String {
        switch self {
        case .twelveHour: return "12-hour"
        case .twentyFourHour: return "24-hour"
        }
    }
}

enum MapStyle: String, Codable, CaseIterable {
    case standard
    case satellite
    case hybrid
    case dark
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .dark: return "Dark"
        }
    }
}

struct SubscriptionStatus: Codable, Equatable {
    var isSubscribed: Bool
    var subscriptionTier: SubscriptionTier
    var expirationDate: Date?
    var isTrialing: Bool
    
    init(
        isSubscribed: Bool = false,
        subscriptionTier: SubscriptionTier = .free,
        expirationDate: Date? = nil,
        isTrialing: Bool = false
    ) {
        self.isSubscribed = isSubscribed
        self.subscriptionTier = subscriptionTier
        self.expirationDate = expirationDate
        self.isTrialing = isTrialing
    }
}

enum SubscriptionTier: String, Codable {
    case free
    case premium
    case family
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .family: return "Family"
        }
    }
    
    var maxTrips: Int {
        switch self {
        case .free: return 3
        case .premium: return 50
        case .family: return 100
        }
    }
}

