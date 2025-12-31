//
// CommuteActivity.swift
// CommuteTimely
//
// ActivityKit attributes for Live Activities and Dynamic Island
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct CommuteActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var firstName: String
        var leaveTime: Date
        var travelTimeMinutes: Int
        var trafficSeverity: TrafficSeverity
        var weatherCondition: WeatherCondition
        var destinationName: String
        var destinationEmoji: String?
        var lastUpdated: Date
        var countdownMinutes: Int
        var eta: Date
        
        // Navigation mode properties
        var isNavigating: Bool = false
        var distanceRemainingKm: Double = 0
        var progressPercent: Int = 0
        var currentSpeedKmh: Int = 0
        var etaMinutes: Int = 0
        
        var trafficColor: String {
            switch trafficSeverity {
            case .clear: return "green"
            case .light: return "yellow"
            case .moderate: return "orange"
            case .heavy: return "red"
            case .severe: return "darkRed"
            }
        }
        
        var distanceDisplayText: String {
            if distanceRemainingKm < 1 {
                return "\(Int(distanceRemainingKm * 1000)) m"
            } else {
                return String(format: "%.1f km", distanceRemainingKm)
            }
        }
    }
    
    // Fixed non-changing properties about your activity go here!
    var tripId: String
    var destinationAddress: String
    var destinationLatitude: Double = 0
    var destinationLongitude: Double = 0
}

enum TrafficSeverity: String, Codable {
    case clear
    case light
    case moderate
    case heavy
    case severe
    
    var description: String {
        switch self {
        case .clear: return "Clear"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .severe: return "Severe"
        }
    }
    
    init(from congestionLevel: CongestionLevel) {
        switch congestionLevel {
        case .none: self = .clear
        case .low: self = .light
        case .moderate: self = .moderate
        case .heavy: self = .heavy
        case .severe: self = .severe
        }
    }
}
#endif

