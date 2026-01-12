import Foundation
import UserNotifications

enum NotificationCategorySetup {
    
    /// Setup all notification categories
    static func setupCategories() {
        let categories = [
            createLeaveTimeCategory(),
            createFeedbackCategory()
        ]
        
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
        print("[NotificationSetup] ✅ Notification categories configured")
    }
    
    /// Create leave-time notification category with actions
    private static func createLeaveTimeCategory() -> UNNotificationCategory {
        // Start Trip Action (Yes)
        let startTripAction = UNNotificationAction(
            identifier: NotificationAction.startTrip.rawValue,
            title: "Start Trip",
            options: [.foreground]
        )
        
        // Snooze Options
        let snooze5Action = UNNotificationAction(
            identifier: NotificationAction.snooze5.rawValue,
            title: "Snooze 5m",
            options: []
        )
        
        let snooze10Action = UNNotificationAction(
            identifier: NotificationAction.snooze10.rawValue,
            title: "Snooze 10m",
            options: []
        )
        
        // Abort Action (No)
        let abortAction = UNNotificationAction(
            identifier: NotificationAction.abortTrip.rawValue,
            title: "Abort Trip",
            options: [.destructive]
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.leaveTime.rawValue,
            actions: [startTripAction, snooze5Action, snooze10Action, abortAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Time to leave for your trip",
            options: [.customDismissAction]
        )
    }
    
    /// Create feedback notification category
    private static func createFeedbackCategory() -> UNNotificationCategory {
        let positiveAction = UNNotificationAction(
            identifier: NotificationAction.feedbackPositive.rawValue,
            title: "Yes, on time! 🚀",
            options: []
        )
        
        let negativeAction = UNNotificationAction(
            identifier: NotificationAction.feedbackNegative.rawValue,
            title: "No, got late 😕",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.tripFeedback.rawValue,
            actions: [positiveAction, negativeAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Did you arrive on time?",
            options: [.customDismissAction]
        )
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String {
    case leaveTime = "LEAVE_TIME"
    case tripFeedback = "TRIP_FEEDBACK"
}

// MARK: - Notification Actions

enum NotificationAction: String {
    case startTrip = "START_TRIP"
    case snooze5 = "SNOOZE_5"
    case snooze10 = "SNOOZE_10"
    case snooze15 = "SNOOZE_15"
    case abortTrip = "ABORT_TRIP"
    case feedbackPositive = "FEEDBACK_POSITIVE"
    case feedbackNegative = "FEEDBACK_NEGATIVE"
}
