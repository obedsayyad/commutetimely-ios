//
// LeaveTimeNotificationScheduler.swift
// CommuteTimely
//
// Precise leave-time notification scheduler with personalization
//

import Foundation
import UserNotifications

protocol LeaveTimeNotificationSchedulerProtocol {
    func scheduleLeaveTimeNotification(
        for trip: Trip,
        recommendedLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws
    
    func cancelLeaveTimeNotification(for tripId: UUID) async
    func rescheduleLeaveTimeNotification(
        for trip: Trip,
        newLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws
}

final class LeaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol {
    private let center = UNUserNotificationCenter.current()
    private let notificationIdentifierPrefix = "leave_time"
    
    func scheduleLeaveTimeNotification(
        for trip: Trip,
        recommendedLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws {
        // Cancel any existing notification for this trip
        await cancelLeaveTimeNotification(for: trip.id)
        
        // Request permission if needed
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw LeaveTimeNotificationError.permissionDenied
        }
        
        // Build personalized message
        let personalizedName = firstName ?? "there"
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let leaveTimeStr = formatter.string(from: recommendedLeaveTime)
        let arrivalTimeStr = formatter.string(from: trip.arrivalTime)
        
        let title = "Time to head out, \(personalizedName)"
        let body = buildNotificationBody(
            explanation: explanation,
            leaveTime: leaveTimeStr,
            arrivalTime: arrivalTimeStr,
            destination: trip.destination.displayName
        )
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "LEAVE_TIME"
        
        // Use natural, reassuring language
        content.userInfo = [
            "tripId": trip.id.uuidString,
            "type": "leave_time",
            "leaveTime": recommendedLeaveTime.timeIntervalSince1970,
            "arrivalTime": trip.arrivalTime.timeIntervalSince1970,
            "destination": trip.destination.displayName,
            "personalized": true,
            "firstName": firstName ?? "there"
        ]
        
        // Create calendar trigger for precise timing
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: recommendedLeaveTime)
        
        guard let triggerDate = calendar.date(from: components) else {
            throw LeaveTimeNotificationError.invalidDateComponents
        }
        
        // Ensure trigger is in the future
        guard triggerDate > Date() else {
            throw LeaveTimeNotificationError.leaveTimeInPast
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create and schedule request
        let identifier = "\(notificationIdentifierPrefix)_\(trip.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        try await center.add(request)
    }
    
    func cancelLeaveTimeNotification(for tripId: UUID) async {
        let identifier = "\(notificationIdentifierPrefix)_\(tripId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func rescheduleLeaveTimeNotification(
        for trip: Trip,
        newLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws {
        // Cancel existing notification
        await cancelLeaveTimeNotification(for: trip.id)
        
        // Schedule new notification
        try await scheduleLeaveTimeNotification(
            for: trip,
            recommendedLeaveTime: newLeaveTime,
            explanation: explanation,
            firstName: firstName
        )
    }
    
    private func buildNotificationBody(
        explanation: String,
        leaveTime: String,
        arrivalTime: String,
        destination: String
    ) -> String {
        // Build personalized, natural-sounding message
        var parts: [String] = []
        
        // Extract key information from explanation
        if explanation.contains("Heavy Traffic") || explanation.contains("Severe Traffic") {
            parts.append("Heavy traffic expected")
        } else if explanation.contains("Moderate Traffic") {
            parts.append("Moderate traffic on your route")
        }
        
        if explanation.contains("weather") && explanation.contains("min") {
            // Extract weather delay
            if let weatherRange = explanation.range(of: #"\d+\s+min\s+weather"#, options: .regularExpression) {
                let weatherText = String(explanation[weatherRange])
                if let minutes = weatherText.components(separatedBy: " ").first {
                    parts.append("\(minutes)-minute weather delay")
                }
            }
        }
        
        // Build main instruction
        if parts.isEmpty {
            // Simple case: just tell them when to leave
            return "Leave by \(leaveTime) to reach \(destination) by \(arrivalTime)"
        } else {
            // Complex case: explain why and when
            let reason = parts.joined(separator: " — ")
            return "\(reason). Leave by \(leaveTime) to reach \(destination) by \(arrivalTime)"
        }
    }
}

// MARK: - Errors

enum LeaveTimeNotificationError: LocalizedError {
    case permissionDenied
    case invalidDateComponents
    case leaveTimeInPast
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission is required to schedule leave-time alerts"
        case .invalidDateComponents:
            return "Invalid date components for notification scheduling"
        case .leaveTimeInPast:
            return "Cannot schedule notification for a time in the past"
        }
    }
}

// MARK: - Mock Service

class MockLeaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol {
    var scheduledNotifications: [UUID: Date] = [:]
    
    func scheduleLeaveTimeNotification(
        for trip: Trip,
        recommendedLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws {
        scheduledNotifications[trip.id] = recommendedLeaveTime
    }
    
    func cancelLeaveTimeNotification(for tripId: UUID) async {
        scheduledNotifications.removeValue(forKey: tripId)
    }
    
    func rescheduleLeaveTimeNotification(
        for trip: Trip,
        newLeaveTime: Date,
        explanation: String,
        firstName: String?
    ) async throws {
        scheduledNotifications[trip.id] = newLeaveTime
    }
}

