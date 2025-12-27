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
        
        var trafficColor: String {
            switch trafficSeverity {
            case .clear: return "green"
            case .light: return "yellow"
            case .moderate: return "orange"
            case .heavy: return "red"
            case .severe: return "darkRed"
            }
        }
    }
    
    // Fixed non-changing properties about your activity go here!
    var tripId: String
    var destinationAddress: String
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

