//
// PersonalizedNotificationScheduler.swift
// CommuteTimely
//
// Service for scheduling personalized daily notifications with 7-day rotation
//

import Foundation
import UserNotifications
import Combine

protocol PersonalizedNotificationSchedulerProtocol {
    func scheduleDailyNotifications(firstName: String) async throws
    func cancelAllPersonalizedNotifications() async
    func updateScheduleIfNeeded() async
    func getCurrentDayIndex() async -> Int
    func requestPermissionIfNeeded() async -> Bool
}

final class PersonalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol {
    private let authManager: AuthSessionController
    private let userPreferencesService: UserPreferencesServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let center = UNUserNotificationCenter.current()
    
    private let notificationIdentifierPrefix = "personalized_daily"
    
    // 7 unique message templates
    private let messageTemplates: [String] = [
        "Good morning, {firstName} — This week starts strong. Let's plan your commute today.",
        "Hey {firstName}, ready to tackle Tuesday? Check your commute times.",
        "Midweek momentum, {firstName}! Your commute insights are ready.",
        "Thursday vibes, {firstName} — Stay ahead with smart commute planning.",
        "Friday energy, {firstName}! Plan your weekend commute now.",
        "Weekend prep, {firstName} — Your commute schedule awaits.",
        "Sunday reset, {firstName}. Get ready for a smooth week ahead."
    ]
    
    init(
        authManager: AuthSessionController,
        userPreferencesService: UserPreferencesServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.authManager = authManager
        self.userPreferencesService = userPreferencesService
        self.notificationService = notificationService
    }
    
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            return true
        }
        
        do {
            return try await notificationService.requestAuthorization()
        } catch {
            print("[PersonalizedNotifications] Failed to request authorization: \(error)")
            return false
        }
    }
    
    func scheduleDailyNotifications(firstName: String) async throws {
        // Cancel existing notifications first
        await cancelAllPersonalizedNotifications()
        
        // Get current preferences
        var preferences = await userPreferencesService.loadPreferences()
        let dayIndex = preferences.notificationSettings.personalizedNotificationDayIndex
        
        // Schedule 7 notifications, one for each day
        for i in 0..<7 {
            let messageIndex = (dayIndex + i) % 7
            let message = messageTemplates[messageIndex].replacingOccurrences(of: "{firstName}", with: firstName)
            
            let content = UNMutableNotificationContent()
            content.title = "CommuteTimely"
            content.body = message
            content.sound = .default
            content.userInfo = [
                "type": "personalized_daily",
                "dayNumber": messageIndex + 1
            ]
            
            // Calculate trigger date (i days from now at the scheduled time)
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            dateComponents.hour = preferences.notificationSettings.personalizedNotificationHour
            dateComponents.minute = preferences.notificationSettings.personalizedNotificationMinute
            
            guard var triggerDate = calendar.date(from: dateComponents) else {
                throw PersonalizedNotificationError.invalidDateComponents
            }
            
            // If the time has already passed today, start scheduling from tomorrow
            if triggerDate < Date() {
                triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
            }
            
            // Add i days to get the date for this notification
            triggerDate = calendar.date(byAdding: .day, value: i, to: triggerDate) ?? triggerDate
            
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
            let identifier = "\(notificationIdentifierPrefix)_\(messageIndex)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            try await center.add(request)
        }
        
        // Update day index for next cycle (increment by 1, so next scheduling starts with next message)
        preferences.notificationSettings.personalizedNotificationDayIndex = (dayIndex + 1) % 7
        try await userPreferencesService.updatePreferences(preferences)
    }
    
    func cancelAllPersonalizedNotifications() async {
        let pendingRequests = await center.pendingNotificationRequests()
        let identifiers = pendingRequests
            .filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func updateScheduleIfNeeded() async {
        let preferences = await userPreferencesService.loadPreferences()
        
        guard preferences.notificationSettings.personalizedDailyNotificationsEnabled else {
            await cancelAllPersonalizedNotifications()
            return
        }
        
        // Check if we have permission
        let hasPermission = await requestPermissionIfNeeded()
        guard hasPermission else {
            print("[PersonalizedNotifications] Permission not granted, cannot schedule")
            return
        }
        
        // Check if we need to reschedule (all notifications have been delivered or are past)
        let pendingRequests = await center.pendingNotificationRequests()
        let personalizedPending = pendingRequests.filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }
        
        // If we have fewer than 3 pending notifications, reschedule to ensure we always have a week ahead
        if personalizedPending.count < 3 {
            // Get firstName from auth manager
            let firstName = authManager.currentUser?.firstName ?? "Friend"
            
            do {
                try await scheduleDailyNotifications(firstName: firstName)
            } catch {
                print("[PersonalizedNotifications] Failed to update schedule: \(error)")
            }
        }
    }
    
    func getCurrentDayIndex() async -> Int {
        let preferences = await userPreferencesService.loadPreferences()
        return preferences.notificationSettings.personalizedNotificationDayIndex
    }
}

// MARK: - Errors

enum PersonalizedNotificationError: LocalizedError {
    case invalidDateComponents
    case permissionDenied
    case firstNameUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidDateComponents:
            return "Invalid date components for notification scheduling"
        case .permissionDenied:
            return "Notification permission denied"
        case .firstNameUnavailable:
            return "User first name is not available"
        }
    }
}

// MARK: - Mock Service

class MockPersonalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol {
    var scheduledNotifications: [String] = []
    var currentDayIndex: Int = 0
    var permissionGranted: Bool = true
    
    func scheduleDailyNotifications(firstName: String) async throws {
        scheduledNotifications = Array(repeating: firstName, count: 7)
    }
    
    func cancelAllPersonalizedNotifications() async {
        scheduledNotifications.removeAll()
    }
    
    func updateScheduleIfNeeded() async {
        // Mock implementation
    }
    
    func getCurrentDayIndex() async -> Int {
        return currentDayIndex
    }
    
    func requestPermissionIfNeeded() async -> Bool {
        return permissionGranted
    }
}

