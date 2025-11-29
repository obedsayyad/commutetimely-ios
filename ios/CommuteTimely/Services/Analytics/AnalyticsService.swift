//
// AnalyticsService.swift
// CommuteTimely
//
// Pluggable analytics service with Mixpanel adapter
//

import Foundation

protocol AnalyticsServiceProtocol {
    func setEnabled(_ enabled: Bool)
    func setUserId(_ userId: String?)
    func trackEvent(_ event: AnalyticsEvent)
    func trackScreen(_ screenName: String)
    func setUserProperty(_ key: String, value: String?)
}

// MARK: - Analytics Events

enum AnalyticsEvent {
    case tripCreated(destination: String, arrivalTime: Date)
    case predictionShown(confidence: Double, leaveTime: Date)
    case notificationSent(tripId: String)
    case notificationOpened(tripId: String)
    case purchaseCompleted(productId: String, price: Double)
    case predictionAccepted(tripId: String)
    case predictionIgnored(tripId: String)
    case onboardingCompleted
    case onboardingAuthSkipped
    case subscriptionStarted(tier: String)
    case themeChanged(from: String, to: String)
    case authSignUp(provider: String)
    case authLoginSuccess(provider: String, method: String)
    case authLoginFailed(provider: String, errorDescription: String)
    case authAccountLinked(fromProvider: String, toProvider: String)
    case authAccountUnlinked(provider: String)
    
    var name: String {
        switch self {
        case .tripCreated: return "trip_created"
        case .predictionShown: return "prediction_shown"
        case .notificationSent: return "notification_sent"
        case .notificationOpened: return "notification_opened"
        case .purchaseCompleted: return "purchase_completed"
        case .predictionAccepted: return "prediction_accepted"
        case .predictionIgnored: return "prediction_ignored"
        case .onboardingCompleted: return "onboarding_completed"
        case .subscriptionStarted: return "subscription_started"
        case .themeChanged: return "theme_changed"
        case .authSignUp: return "sign_up"
        case .authLoginSuccess: return "login_success"
        case .authLoginFailed: return "login_failed"
        case .authAccountLinked: return "account_linked"
        case .authAccountUnlinked: return "account_unlinked"
        case .onboardingAuthSkipped: return "onboarding_auth_skipped"
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .tripCreated(let destination, let arrivalTime):
            return [
                "destination": destination,
                "arrival_time": arrivalTime.timeIntervalSince1970
            ]
        case .predictionShown(let confidence, let leaveTime):
            return [
                "confidence": confidence,
                "leave_time": leaveTime.timeIntervalSince1970
            ]
        case .notificationSent(let tripId), .notificationOpened(let tripId):
            return ["trip_id": tripId]
        case .purchaseCompleted(let productId, let price):
            return [
                "product_id": productId,
                "price": price
            ]
        case .predictionAccepted(let tripId), .predictionIgnored(let tripId):
            return ["trip_id": tripId]
        case .onboardingCompleted:
            return [:]
        case .subscriptionStarted(let tier):
            return ["tier": tier]
        case .themeChanged(let from, let to):
            return [
                "from_theme": from,
                "to_theme": to
            ]
        case .authSignUp(let provider):
            return ["provider": provider]
        case .authLoginSuccess(let provider, let method):
            return [
                "provider": provider,
                "method": method
            ]
        case .authLoginFailed(let provider, let errorDescription):
            return [
                "provider": provider,
                "error": errorDescription
            ]
        case .authAccountLinked(let fromProvider, let toProvider):
            return [
                "from_provider": fromProvider,
                "to_provider": toProvider
            ]
        case .authAccountUnlinked(let provider):
            return ["provider": provider]
        case .onboardingAuthSkipped:
            return [:]
        }
    }
}

// MARK: - Composite Analytics Service

class CompositeAnalyticsService: AnalyticsServiceProtocol {
    private var adapters: [AnalyticsAdapter]
    private var isEnabled = false
    
    init(adapters: [AnalyticsAdapter]) {
        self.adapters = adapters
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        adapters.forEach { $0.setEnabled(enabled) }
    }
    
    func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        adapters.forEach { $0.setUserId(userId) }
    }
    
    func trackEvent(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        adapters.forEach { $0.trackEvent(event.name, parameters: event.parameters) }
    }
    
    func trackScreen(_ screenName: String) {
        guard isEnabled else { return }
        adapters.forEach { $0.trackScreen(screenName) }
    }
    
    func setUserProperty(_ key: String, value: String?) {
        guard isEnabled else { return }
        adapters.forEach { $0.setUserProperty(key, value: value) }
    }
}

// MARK: - Analytics Adapter Protocol

protocol AnalyticsAdapter {
    func setEnabled(_ enabled: Bool)
    func setUserId(_ userId: String?)
    func trackEvent(_ eventName: String, parameters: [String: Any])
    func trackScreen(_ screenName: String)
    func setUserProperty(_ key: String, value: String?)
}

// MARK: - Mixpanel Analytics Adapter

class MixpanelAnalyticsAdapter: AnalyticsAdapter {
    private let token: String
    private var isEnabled = false
    
    init(token: String) {
        self.token = token
        // In a real implementation:
        // Mixpanel.initialize(token: token)
    }
    
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        // In a real implementation:
        // Mixpanel.mainInstance().optInTracking() or optOutTracking()
    }
    
    func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        // In a real implementation:
        // Mixpanel.mainInstance().identify(distinctId: userId ?? "")
        print("[Mixpanel] Set user ID: \(userId ?? "nil")")
    }
    
    func trackEvent(_ eventName: String, parameters: [String: Any]) {
        guard isEnabled else { return }
        // In a real implementation:
        // Mixpanel.mainInstance().track(event: eventName, properties: parameters)
        print("[Mixpanel] Event: \(eventName), Properties: \(parameters)")
    }
    
    func trackScreen(_ screenName: String) {
        guard isEnabled else { return }
        // In a real implementation:
        // Mixpanel.mainInstance().track(event: "Screen View", properties: ["screen_name": screenName])
        print("[Mixpanel] Screen: \(screenName)")
    }
    
    func setUserProperty(_ key: String, value: String?) {
        guard isEnabled else { return }
        // In a real implementation:
        // Mixpanel.mainInstance().people.set(property: key, to: value ?? "")
        print("[Mixpanel] User property: \(key) = \(value ?? "nil")")
    }
}

// MARK: - Mock Service

class MockAnalyticsService: AnalyticsServiceProtocol {
    var isEnabled = false
    var userId: String?
    var trackedEvents: [String] = []
    var trackedScreens: [String] = []
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    func setUserId(_ userId: String?) {
        self.userId = userId
    }
    
    func trackEvent(_ event: AnalyticsEvent) {
        trackedEvents.append(event.name)
    }
    
    func trackScreen(_ screenName: String) {
        trackedScreens.append(screenName)
    }
    
    func setUserProperty(_ key: String, value: String?) {
        // Mock implementation
    }
}

