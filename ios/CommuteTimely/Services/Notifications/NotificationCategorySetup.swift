//
// NotificationCategorySetup.swift
// CommuteTimely
//
// Setup for notification categories and actions
//

import Foundation
import UserNotifications

enum NotificationCategorySetup {
    
    /// Setup all notification categories
    static func setupCategories() {
        let categories = [
            createLeaveTimeCategory()
        ]
        
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
        print("[NotificationSetup] ✅ Notification categories configured")
    }
    
    /// Create leave-time notification category with actions
    private static func createLeaveTimeCategory() -> UNNotificationCategory {
        // Start Trip Action
        let startTripAction = UNNotificationAction(
            identifier: NotificationAction.startTrip.rawValue,
            title: "Start Trip",
            options: [.foreground]
        )
        
        // Dismiss Action
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.leaveTime.rawValue,
            actions: [startTripAction, dismissAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Time to leave for your trip",
            options: [.customDismissAction]
        )
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String {
    case leaveTime = "LEAVE_TIME"
}

// MARK: - Notification Actions

enum NotificationAction: String {
    case startTrip = "START_TRIP"
    case dismiss = "DISMISS"
}
