//
// CommuteActivityManager.swift
// CommuteTimely
//
// Service for managing Live Activities and Dynamic Island updates
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

protocol CommuteActivityManagerProtocol {
    func startActivity(for trip: Trip, recommendation: LeaveTimeRecommendation, firstName: String?) async throws
    func updateActivity(for tripId: UUID, recommendation: LeaveTimeRecommendation, firstName: String?) async
    func endActivity(for tripId: UUID) async
    func endAllActivities() async
    func isActivityActive(for tripId: UUID) async -> Bool
    func areActivitiesEnabled() async -> Bool
}

final class CommuteActivityManager: CommuteActivityManagerProtocol {
    private let throttler = Throttler(interval: 30) // Update at most every 30 seconds
    
    func areActivitiesEnabled() async -> Bool {
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            return ActivityAuthorizationInfo().areActivitiesEnabled
            #else
            return false
            #endif
        }
        return false
    }
    
    func startActivity(
        for trip: Trip,
        recommendation: LeaveTimeRecommendation,
        firstName: String?
    ) async throws {
        guard #available(iOS 16.1, *) else {
            throw CommuteActivityError.notSupported
        }
        
        #if canImport(ActivityKit)
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw CommuteActivityError.activitiesDisabled
        }
        
        // End any existing activity for this trip
        await endActivity(for: trip.id)
        
        let attributes = CommuteActivityAttributes(
            tripId: trip.id.uuidString,
            destinationAddress: trip.destination.address
        )
        
        let contentState = buildContentState(
            trip: trip,
            recommendation: recommendation,
            firstName: firstName
        )
        
        let activityContent = ActivityContent(state: contentState, staleDate: Date().addingTimeInterval(300))
        
        do {
            _ = try Activity<CommuteActivityAttributes>.request(
                attributes: attributes,
                content: activityContent,
                pushType: .token
            )
            
            print("[CommuteActivity] Started Live Activity for trip \(trip.id)")
        } catch {
            print("[CommuteActivity] Failed to start activity: \(error)")
            throw CommuteActivityError.startFailed(error)
        }
        #else
        throw CommuteActivityError.notSupported
        #endif
    }
    
    func updateActivity(
        for tripId: UUID,
        recommendation: LeaveTimeRecommendation,
        firstName: String?
    ) async {
        guard #available(iOS 16.1, *) else {
            return
        }
        
        #if canImport(ActivityKit)
        // Throttle updates (unless major change detected)
        let shouldUpdate = await throttler.shouldExecute()
        guard shouldUpdate else {
            return
        }
        
        guard let activity = findActivity(for: tripId) else {
            return
        }
        
        // Build content state from recommendation
        // Note: In production, we'd fetch trip from storage for destination name
        let contentState = buildContentStateFromRecommendation(
            recommendation: recommendation,
            firstName: firstName,
            destinationName: activity.attributes.destinationAddress
        )
        
        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300)
        )
        
        await activity.update(activityContent)
        #endif
    }
    
    func endActivity(for tripId: UUID) async {
        guard #available(iOS 16.1, *) else {
            return
        }
        
        #if canImport(ActivityKit)
        guard let activity = findActivity(for: tripId) else {
            return
        }
        
        // Use the current activity content when ending
        await activity.end(activity.content, dismissalPolicy: .immediate)
        #endif
    }
    
    func endAllActivities() async {
        guard #available(iOS 16.1, *) else {
            return
        }
        
        #if canImport(ActivityKit)
        let activities = Activity<CommuteActivityAttributes>.activities
        for activity in activities {
            // Use the current activity content when ending
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        #endif
    }
    
    func isActivityActive(for tripId: UUID) async -> Bool {
        guard #available(iOS 16.1, *) else {
            return false
        }
        
        #if canImport(ActivityKit)
        return findActivity(for: tripId) != nil
        #else
        return false
        #endif
    }
    
    // MARK: - Private Helpers
    
    @available(iOS 16.1, *)
    private func findActivity(for tripId: UUID) -> Activity<CommuteActivityAttributes>? {
        #if canImport(ActivityKit)
        return Activity<CommuteActivityAttributes>.activities.first { activity in
            activity.attributes.tripId == tripId.uuidString
        }
        #else
        return nil
        #endif
    }
    
    private func buildContentState(
        trip: Trip,
        recommendation: LeaveTimeRecommendation,
        firstName: String?
    ) -> CommuteActivityAttributes.ContentState {
        let leaveTime = recommendation.recommendedLeaveTimeUtc
        let now = Date()
        let countdownMinutes = max(0, Int((leaveTime.timeIntervalSince(now)) / 60))
        
        return CommuteActivityAttributes.ContentState(
            firstName: firstName ?? "there",
            leaveTime: leaveTime,
            travelTimeMinutes: Int(recommendation.snapshot.route.totalDurationWithTraffic / 60),
            trafficSeverity: TrafficSeverity(from: recommendation.snapshot.route.congestionLevel),
            weatherCondition: recommendation.snapshot.weather.conditions,
            destinationName: trip.destination.displayName,
            destinationEmoji: emojiForDestination(trip.destination),
            lastUpdated: Date(),
            countdownMinutes: countdownMinutes,
            eta: trip.arrivalTime
        )
    }
    
    private func buildContentStateFromRecommendation(
        recommendation: LeaveTimeRecommendation,
        firstName: String?,
        destinationName: String
    ) -> CommuteActivityAttributes.ContentState {
        let leaveTime = recommendation.recommendedLeaveTimeUtc
        let now = Date()
        let countdownMinutes = max(0, Int((leaveTime.timeIntervalSince(now)) / 60))
        
        return CommuteActivityAttributes.ContentState(
            firstName: firstName ?? "there",
            leaveTime: leaveTime,
            travelTimeMinutes: Int(recommendation.snapshot.route.totalDurationWithTraffic / 60),
            trafficSeverity: TrafficSeverity(from: recommendation.snapshot.route.congestionLevel),
            weatherCondition: recommendation.snapshot.weather.conditions,
            destinationName: destinationName,
            destinationEmoji: nil,
            lastUpdated: Date(),
            countdownMinutes: countdownMinutes,
            eta: Date().addingTimeInterval(recommendation.snapshot.route.totalDurationWithTraffic)
        )
    }
    
    private func emojiForDestination(_ destination: Location) -> String? {
        // Map place types to emojis
        if let placeType = destination.placeType {
            switch placeType {
            case .home: return "🏠"
            case .work: return "🏢"
            case .school: return "🎓"
            case .gym: return "💪"
            case .restaurant: return "🍽️"
            case .shop: return "🛍️"
            case .other: return nil
            }
        }
        return nil
    }
}

// MARK: - Errors

enum CommuteActivityError: LocalizedError {
    case activitiesDisabled
    case notSupported
    case startFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            return "Live Activities are disabled. Please enable them in Settings."
        case .notSupported:
            return "Live Activities require iOS 16.1 or later."
        case .startFailed(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        }
    }
}

// MARK: - Throttler

actor Throttler {
    private let interval: TimeInterval
    private var lastExecution: Date = .distantPast
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func shouldExecute() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastExecution) >= interval else {
            return false
        }
        lastExecution = now
        return true
    }
}

// MARK: - Mock for Testing

class MockCommuteActivityManager: CommuteActivityManagerProtocol {
    func areActivitiesEnabled() async -> Bool {
        return true
    }
    var activeActivities: [UUID] = []
    
    func startActivity(for trip: Trip, recommendation: LeaveTimeRecommendation, firstName: String?) async throws {
        activeActivities.append(trip.id)
    }
    
    func updateActivity(for tripId: UUID, recommendation: LeaveTimeRecommendation, firstName: String?) async {
        // Mock implementation
    }
    
    func endActivity(for tripId: UUID) async {
        activeActivities.removeAll { $0 == tripId }
    }
    
    func endAllActivities() async {
        activeActivities.removeAll()
    }
    
    func isActivityActive(for tripId: UUID) async -> Bool {
        return activeActivities.contains(tripId)
    }
}

