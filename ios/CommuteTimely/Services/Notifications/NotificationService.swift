//
// NotificationService.swift
// CommuteTimely
//
// Service for scheduling and managing local notifications
//

import Foundation
import UserNotifications
import Combine

protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func scheduleNotification(for trip: Trip, at leaveTime: Date, prediction: Prediction) async throws
    func cancelNotification(for tripId: UUID) async
    func rescheduleNotification(for trip: Trip, newLeaveTime: Date, reason: String) async throws
    func registerBackgroundTasks()
}

class NotificationService: NSObject, NotificationServiceProtocol {
    private let mlPredictionService: MLPredictionServiceProtocol
    private let tripStorageService: TripStorageServiceProtocol
    private let center = UNUserNotificationCenter.current()
    
    init(mlPredictionService: MLPredictionServiceProtocol, tripStorageService: TripStorageServiceProtocol) {
        self.mlPredictionService = mlPredictionService
        self.tripStorageService = tripStorageService
        super.init()
        center.delegate = self
        setupNotificationCategories()
    }
    
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]
        return try await center.requestAuthorization(options: options)
    }
    
    func scheduleNotification(for trip: Trip, at leaveTime: Date, prediction: Prediction) async throws {
        // Cancel existing notifications for this trip
        await cancelNotification(for: trip.id)
        
        // Main notification at leave time
        if trip.notificationSettings.enableMainNotification {
            let mainNotification = createMainNotificationContent(for: trip, prediction: prediction)
            let mainTrigger = createTrigger(for: leaveTime)
            let mainRequest = UNNotificationRequest(
                identifier: "trip_\(trip.id.uuidString)_main",
                content: mainNotification,
                trigger: mainTrigger
            )
            try await center.add(mainRequest)
        }
        
        // Reminder notifications
        if trip.notificationSettings.enableReminderNotifications {
            for offset in trip.notificationSettings.reminderOffsets {
                let reminderTime = leaveTime.addingTimeInterval(-Double(offset * 60))
                
                // Only schedule if reminder is in the future
                guard reminderTime > Date() else { continue }
                
                let reminderContent = createReminderNotificationContent(
                    for: trip,
                    minutesUntilLeave: offset
                )
                let reminderTrigger = createTrigger(for: reminderTime)
                let reminderRequest = UNNotificationRequest(
                    identifier: "trip_\(trip.id.uuidString)_reminder_\(offset)",
                    content: reminderContent,
                    trigger: reminderTrigger
                )
                try await center.add(reminderRequest)
            }
        }
    }
    
    func cancelNotification(for tripId: UUID) async {
        let identifiers = await center.pendingNotificationRequests()
            .filter { $0.identifier.contains(tripId.uuidString) }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func rescheduleNotification(for trip: Trip, newLeaveTime: Date, reason: String) async throws {
        // Create a prediction placeholder (in real app, fetch new prediction)
        let placeholderPrediction = Prediction(
            leaveTime: newLeaveTime,
            confidence: 0.8,
            explanation: reason,
            alternativeLeaveTimes: [],
            bufferMinutes: trip.bufferMinutes,
            predictionSource: .cached,
            predictedAt: Date()
        )
        
        try await scheduleNotification(for: trip, at: newLeaveTime, prediction: placeholderPrediction)
        
        // Send an update notification with natural language
        let updateContent = UNMutableNotificationContent()
        updateContent.title = "Leave Time Updated"
        updateContent.body = "I've adjusted your departure time for \(trip.destination.displayName). \(reason)"
        updateContent.sound = .default
        updateContent.categoryIdentifier = "TRIP_UPDATE"
        
        let updateRequest = UNNotificationRequest(
            identifier: "trip_\(trip.id.uuidString)_update",
            content: updateContent,
            trigger: nil // Immediate
        )
        
        try await center.add(updateRequest)
    }
    
    func registerBackgroundTasks() {
        // In a real implementation:
        // BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.commutetimely.refresh", using: nil) { task in
        //     self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        // }
        print("[Notifications] Background tasks registered")
    }
    
    // MARK: - Private Helpers
    
    private func createMainNotificationContent(for trip: Trip, prediction: Prediction) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // Vary the message for naturalness
        let messages = [
            "Time to leave for \(trip.destination.displayName)!",
            "Ready to go? Head to \(trip.destination.displayName) now",
            "Leave now to reach \(trip.destination.displayName) on time"
        ]
        content.title = messages.randomElement() ?? messages[0]
        
        content.body = "\(prediction.explanation). Confidence: \(prediction.confidencePercentage)%"
        content.sound = trip.notificationSettings.soundEnabled ? .default : nil
        content.categoryIdentifier = "TRIP_DEPARTURE"
        content.userInfo = [
            "tripId": trip.id.uuidString,
            "leaveTime": prediction.leaveTime.timeIntervalSince1970
        ]
        
        return content
    }
    
    private func createReminderNotificationContent(for trip: Trip, minutesUntilLeave: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Trip"
        content.body = "Leave in \(minutesUntilLeave) minutes for \(trip.destination.displayName)"
        content.sound = trip.notificationSettings.soundEnabled ? .default : nil
        content.categoryIdentifier = "TRIP_REMINDER"
        content.userInfo = ["tripId": trip.id.uuidString]
        
        return content
    }
    
    private func createTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
    
    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 5 min",
            options: []
        )
        
        let navigateAction = UNNotificationAction(
            identifier: "NAVIGATE_ACTION",
            title: "Navigate",
            options: [.foreground]
        )
        
        let startTripAction = UNNotificationAction(
            identifier: "START_TRIP_ACTION",
            title: "🚗 Start Trip",
            options: [.foreground]
        )
        
        let notNowAction = UNNotificationAction(
            identifier: "NOT_NOW_ACTION",
            title: "Not Now",
            options: [.destructive]
        )
        
        let departureCategory = UNNotificationCategory(
            identifier: "TRIP_DEPARTURE",
            actions: [startTripAction, notNowAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "TRIP_REMINDER",
            actions: [navigateAction],
            intentIdentifiers: [],
            options: []
        )
        
        let updateCategory = UNNotificationCategory(
            identifier: "TRIP_UPDATE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([departureCategory, reminderCategory, updateCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let tripIdString = userInfo["tripId"] as? String else {
            completionHandler()
            return
        }
        
        print("[Notifications] Handling action: \(response.actionIdentifier) for trip: \(tripIdString)")
        
        switch response.actionIdentifier {
        case NotificationAction.startTrip.rawValue:
            // "Yes" -> Start Trip
            handleStartTrip(userInfo: userInfo)
            
        case NotificationAction.snooze5.rawValue:
            // "No" -> Snooze 5m
            handleSnooze(minutes: 5, userInfo: userInfo)
            
        case NotificationAction.snooze10.rawValue:
            // "No" -> Snooze 10m
            handleSnooze(minutes: 10, userInfo: userInfo)
            
        case NotificationAction.abortTrip.rawValue:
            // "No" -> Abort Trip
            handleAbortTrip(userInfo: userInfo)
            
        case NotificationAction.feedbackPositive.rawValue:
            // "Arrived on time" -> Yes
            handleFeedback(isPositive: true, userInfo: userInfo)
            
        case NotificationAction.feedbackNegative.rawValue:
            // "Late" -> No
            handleFeedback(isPositive: false, userInfo: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleSnooze(minutes: Int, userInfo: [AnyHashable: Any]) {
        guard let tripIdString = userInfo["tripId"] as? String else { return }
        
        print("[Notifications] Snoozing trip \(tripIdString) for \(minutes) min")
        
        // Post notification for coordinator to handle rescheduling
        NotificationCenter.default.post(
            name: .snoozeTrip,
            object: nil,
            userInfo: [
                "tripId": tripIdString,
                "minutes": minutes
            ]
        )
    }
    
    private func handleStartTrip(userInfo: [AnyHashable: Any]) {
        // Start live navigation mode
        print("[Notifications] Starting trip navigation")
        guard let tripIdString = userInfo["tripId"] as? String else { return }
        NotificationCenter.default.post(
            name: .startTripNavigation,
            object: nil,
            userInfo: ["tripId": tripIdString]
        )
    }
    
    private func handleAbortTrip(userInfo: [AnyHashable: Any]) {
        print("[Notifications] Aborting trip")
        guard let tripIdString = userInfo["tripId"] as? String else { return }
        NotificationCenter.default.post(
            name: .abortTrip,
            object: nil,
            userInfo: ["tripId": tripIdString]
        )
    }
    
    private func handleFeedback(isPositive: Bool, userInfo: [AnyHashable: Any]) {
        print("[Notifications] Received feedback: \(isPositive ? "Positive" : "Negative")")
        guard let tripIdString = userInfo["tripId"] as? String else { return }
        
        // Post notification (optional, maybe just log analytics)
        NotificationCenter.default.post(
            name: .tripFeedbackReceived,
            object: nil,
            userInfo: [
                "tripId": tripIdString,
                "isPositive": isPositive
            ]
        )
        
        // Show immediate alert response (if app is open) OR schedule a local notification thanks?
        // Ideally we just specific logic here.
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startTripNavigation = Notification.Name("startTripNavigation")
    static let snoozeTrip = Notification.Name("snoozeTrip")
    static let abortTrip = Notification.Name("abortTrip")
    static let tripFeedbackReceived = Notification.Name("tripFeedbackReceived")
    static let openNavigation = Notification.Name("openNavigation")
}

// MARK: - Mock Service

class MockNotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool {
        return true
    }
    
    func scheduleNotification(for trip: Trip, at leaveTime: Date, prediction: Prediction) async throws {
        print("[Mock Notifications] Scheduled for \(leaveTime)")
    }
    
    func cancelNotification(for tripId: UUID) async {
        print("[Mock Notifications] Cancelled \(tripId)")
    }
    
    func rescheduleNotification(for trip: Trip, newLeaveTime: Date, reason: String) async throws {
        print("[Mock Notifications] Rescheduled: \(reason)")
    }
    
    func registerBackgroundTasks() {
        print("[Mock Notifications] Background tasks registered")
    }
}

