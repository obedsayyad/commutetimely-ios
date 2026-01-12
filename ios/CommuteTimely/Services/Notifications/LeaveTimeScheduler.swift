//
//  LeaveTimeScheduler.swift
//  CommuteTimely
//
//  Coordinates prediction pipeline with notification scheduling and rescheduling.
//

import Foundation
import Combine
import UserNotifications
import CoreLocation

protocol LeaveTimeSchedulerProtocol {
    func scheduleTrip(_ trip: Trip) async
    func rescheduleTrip(_ trip: Trip, reason: String) async
    func cancelTrip(_ trip: Trip) async
    func handleSignificantLocationChange() async
}

final class LeaveTimeScheduler: LeaveTimeSchedulerProtocol {
    private let predictionEngine: PredictionEngineProtocol
    private let notificationService: NotificationServiceProtocol
    private let leaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol
    private let commuteActivityManager: CommuteActivityManagerProtocol
    private let userPreferencesService: UserPreferencesServiceProtocol
    private let tripStorageService: TripStorageServiceProtocol
    private let locationService: LocationServiceProtocol
    private let authManager: AuthSessionController
    private var cancellable: AnyCancellable?
    private var lastKnownCoordinate: Coordinate?
    private var lastRecalculationCoordinate: Coordinate?
    private var lastRecalculationDate: Date = .distantPast
    private var lastPredictedLeaveTimes: [UUID: Date] = [:]
    
    init(
        predictionEngine: PredictionEngineProtocol,
        notificationService: NotificationServiceProtocol,
        leaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol,
        commuteActivityManager: CommuteActivityManagerProtocol,
        userPreferencesService: UserPreferencesServiceProtocol,
        tripStorageService: TripStorageServiceProtocol,
        locationService: LocationServiceProtocol,
        authManager: AuthSessionController
    ) {
        self.predictionEngine = predictionEngine
        self.notificationService = notificationService
        self.leaveTimeNotificationScheduler = leaveTimeNotificationScheduler
        self.commuteActivityManager = commuteActivityManager
        self.userPreferencesService = userPreferencesService
        self.tripStorageService = tripStorageService
        self.locationService = locationService
        self.authManager = authManager
        observeLocation()
    }
    
    func scheduleTrip(_ trip: Trip) async {
        let recommendation = await makeRecommendation(for: trip)
        await persistSnapshot(recommendation.snapshot, to: trip)
        
        // Get user's first name from auth manager
        let firstName = await MainActor.run {
            authManager.currentUser?.firstName
        }
        
        // Schedule precise leave-time notification
        do {
            try await leaveTimeNotificationScheduler.scheduleLeaveTimeNotification(
                for: trip,
                recommendedLeaveTime: recommendation.recommendedLeaveTimeUtc,
                explanation: recommendation.explanation,
                firstName: firstName
            )
            lastPredictedLeaveTimes[trip.id] = recommendation.recommendedLeaveTimeUtc
        } catch {
            print("[Scheduler] Failed to schedule leave-time notification: \(error)")
            // Fallback to standard notification
            do {
                try await notificationService.scheduleNotification(
                    for: trip,
                    at: recommendation.prediction.leaveTime,
                    prediction: recommendation.prediction
                )
            } catch {
                print("[Scheduler] Failed to schedule fallback notification: \(error)")
            }
        }
        
        // Start Live Activity if enabled
        await startLiveActivityIfEnabled(for: trip, recommendation: recommendation, firstName: firstName)
    }
    
    func rescheduleTrip(_ trip: Trip, reason: String) async {
        let recommendation = await makeRecommendation(for: trip)
        await persistSnapshot(recommendation.snapshot, to: trip)
        
        // Check if leave time changed significantly (≥ 3 minutes)
        let newLeaveTime = recommendation.recommendedLeaveTimeUtc
        if let lastLeaveTime = lastPredictedLeaveTimes[trip.id] {
            let timeDifference = abs(newLeaveTime.timeIntervalSince(lastLeaveTime))
            if timeDifference < 180 { // Less than 3 minutes
                // No significant change, skip rescheduling
                return
            }
        }
        
        // Get user's first name from auth manager
        let firstName = await MainActor.run {
            authManager.currentUser?.firstName
        }
        
        // Build explanation with reason
        let explanation = "\(reason). \(recommendation.explanation)"
        
        // Reschedule precise leave-time notification
        do {
            try await leaveTimeNotificationScheduler.rescheduleLeaveTimeNotification(
                for: trip,
                newLeaveTime: newLeaveTime,
                explanation: explanation,
                firstName: firstName
            )
            lastPredictedLeaveTimes[trip.id] = newLeaveTime
        } catch {
            print("[Scheduler] Failed to reschedule leave-time notification: \(error)")
            // Fallback to standard notification
            do {
                try await notificationService.rescheduleNotification(
                    for: trip,
                    newLeaveTime: recommendation.prediction.leaveTime,
                    reason: reason
                )
            } catch {
                print("[Scheduler] Failed to reschedule fallback notification: \(error)")
            }
        }
        
        // Update Live Activity if enabled
        await updateLiveActivityIfEnabled(for: trip.id, recommendation: recommendation, firstName: firstName)
    }
    
    func cancelTrip(_ trip: Trip) async {
        await leaveTimeNotificationScheduler.cancelLeaveTimeNotification(for: trip.id)
        await notificationService.cancelNotification(for: trip.id)
        await commuteActivityManager.endActivity(for: trip.id)
        lastPredictedLeaveTimes.removeValue(forKey: trip.id)
    }
    
    func handleSignificantLocationChange() async {
        let activeTrips = await tripStorageService.fetchTrips().filter { $0.isActive }
        for trip in activeTrips {
            await rescheduleTrip(trip, reason: "Route updated for your new position")
        }
    }
    
    private func observeLocation() {
        cancellable = locationService.currentLocation
            .compactMap { $0?.coordinate }
            .map { Coordinate(clCoordinate: $0) }
            .sink { [weak self] coordinate in
                guard let self else { return }
                self.lastKnownCoordinate = coordinate
                if self.shouldTriggerReschedule(for: coordinate) {
                    self.lastRecalculationCoordinate = coordinate
                    self.lastRecalculationDate = Date()
                    Task {
                        await self.handleSignificantLocationChange()
                    }
                }
            }
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .startTripNavigation,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleStartTripNavigation(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .snoozeTrip,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSnoozeTrip(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .abortTrip,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAbortTrip(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .tripFeedbackReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTripFeedback(notification)
        }
    }
    
    private func handleStartTripNavigation(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdString) else { return }
        
        Task {
            guard let trip = await tripStorageService.fetchTrip(id: tripId) else { return }
            
            // Switch Dynamic Island to Navigation Mode
            if let currentLoc = lastKnownCoordinate {
                await commuteActivityManager.startNavigationMode(for: tripId, currentLocation: currentLoc)
            }
            
            // Schedule Feedback Notification for arrival time
            // (Assuming arrival is roughly now + travel time, or at scheduled arrival)
            // For simplicity, schedule feedback at expected arrival time
            scheduleFeedbackNotification(for: trip)
            
            print("[Scheduler] Started navigation for trip \(tripId)")
        }
    }
    
    private func handleSnoozeTrip(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdString),
              let minutes = notification.userInfo?["minutes"] as? Int else { return }
        
        Task {
            guard let trip = await tripStorageService.fetchTrip(id: tripId) else { return }
            
            // Calculate new leave time
            let newLeaveTime = Date().addingTimeInterval(Double(minutes * 60))
            let reason = "Snoozed for \(minutes) minutes"
            
            // Reschedule
            try? await leaveTimeNotificationScheduler.rescheduleLeaveTimeNotification(
                for: trip,
                newLeaveTime: newLeaveTime,
                explanation: reason,
                firstName: authManager.currentUser?.firstName
            )
            
            print("[Scheduler] Snoozed trip \(tripId) for \(minutes)m")
        }
    }
    
    private func handleAbortTrip(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdString) else { return }
        
        Task {
            guard let trip = await tripStorageService.fetchTrip(id: tripId) else { return }
            await cancelTrip(trip)
            print("[Scheduler] Aborted trip \(tripId)")
        }
    }
    
    private func handleTripFeedback(_ notification: Notification) {
        // Analytics code would go here
        print("[Scheduler] Feedback received & logged")
    }
    
    private func scheduleFeedbackNotification(for trip: Trip) {
        Task {
            // Schedule "Did you arrive?" notification at arrival time + 5 mins
            let feedbackTime = trip.arrivalTime.addingTimeInterval(300) 
            
            let content = UNMutableNotificationContent()
            content.title = "Trip Complete"
            content.body = "Did you arrive on time?"
            content.categoryIdentifier = "TRIP_FEEDBACK"
            content.userInfo = ["tripId": trip.id.uuidString]
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: feedbackTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "feedback_\(trip.id.uuidString)", content: content, trigger: trigger)
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func shouldTriggerReschedule(for coordinate: Coordinate) -> Bool {
        guard let last = lastRecalculationCoordinate else { return true }
        let movedEnough = coordinate.distance(to: last) > 500 // meters
        let coolDownMet = Date().timeIntervalSince(lastRecalculationDate) > 300
        return movedEnough && coolDownMet
    }
    
    private func makeRecommendation(for trip: Trip) async -> LeaveTimeRecommendation {
        let origin: Coordinate
        switch trip.origin {
        case .currentLocation:
            origin = lastKnownCoordinate ?? Coordinate(latitude: 37.7749, longitude: -122.4194)
        case .customLocation(let location):
            origin = location.coordinate
        }
        
        return await predictionEngine.recommendation(
            origin: origin,
            destination: trip.destination.coordinate,
            arrivalTime: trip.arrivalTime
        )
    }
    
    @MainActor
    private func persistSnapshot(_ snapshot: TrafficWeatherSnapshot, to trip: Trip) async {
        guard var existing = await tripStorageService.fetchTrip(id: trip.id) else { return }
        existing.lastRouteSnapshot = snapshot.makeRouteSnapshot()
        existing.expectedWeatherSummary = snapshot.weather.conditions.description
        existing.bufferMinutes = snapshot.route.totalDurationWithTraffic > 0 ? Int(snapshot.route.totalDurationWithTraffic / 60) : existing.bufferMinutes
        existing.arrivalBufferMinutes = existing.bufferMinutes
        
        do {
            try await tripStorageService.updateTrip(existing)
        } catch {
            print("[Scheduler] Failed to persist snapshot: \(error)")
        }
    }
    
    // MARK: - Live Activity Helpers
    
    private func startLiveActivityIfEnabled(
        for trip: Trip,
        recommendation: LeaveTimeRecommendation,
        firstName: String?
    ) async {
        let preferences = await userPreferencesService.loadPreferences()
        guard preferences.notificationSettings.dynamicIslandUpdatesEnabled else {
            return
        }
        
        guard await commuteActivityManager.areActivitiesEnabled() else {
            return
        }
        
        do {
            try await commuteActivityManager.startActivity(
                for: trip,
                recommendation: recommendation,
                firstName: firstName
            )
        } catch {
            print("[Scheduler] Failed to start Live Activity: \(error)")
        }
    }
    
    private func updateLiveActivityIfEnabled(
        for tripId: UUID,
        recommendation: LeaveTimeRecommendation,
        firstName: String?
    ) async {
        let preferences = await userPreferencesService.loadPreferences()
        guard preferences.notificationSettings.dynamicIslandUpdatesEnabled else {
            return
        }
        
        guard await commuteActivityManager.isActivityActive(for: tripId) else {
            return
        }
        
        await commuteActivityManager.updateActivity(
            for: tripId,
            recommendation: recommendation,
            firstName: firstName
        )
    }
}

// MARK: - TrafficWeatherSnapshot Extension

private extension TrafficWeatherSnapshot {
    func makeRouteSnapshot() -> RouteSnapshot {
        RouteSnapshot(
            travelTimeMinutes: Int(route.totalDurationWithTraffic / 60),
            trafficSummary: route.congestionLevel.description,
            congestionLevel: route.congestionLevel,
            capturedAt: generatedAt,
            distanceMeters: route.distance
        )
    }
}

