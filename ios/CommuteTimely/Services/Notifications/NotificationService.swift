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
            title: "Start Navigation",
            options: [.foreground]
        )
        
        let departureCategory = UNNotificationCategory(
            identifier: "TRIP_DEPARTURE",
            actions: [navigateAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "TRIP_REMINDER",
            actions: [],
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

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            handleSnooze(userInfo: userInfo)
        case "NAVIGATE_ACTION":
            handleNavigate(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleSnooze(userInfo: [AnyHashable: Any]) {
        // Reschedule notification for 5 minutes later
        print("[Notifications] Snoozing notification")
    }
    
    private func handleNavigate(userInfo: [AnyHashable: Any]) {
        // Open navigation app
        print("[Notifications] Opening navigation")
    }
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

