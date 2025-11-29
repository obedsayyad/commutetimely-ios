//
// RouteInfo.swift
// CommuteTimely
//
// Models for route information, traffic, and navigation data
//

import Foundation

struct RouteInfo: Codable, Equatable {
    let distance: Double // meters
    let duration: Double // seconds
    let trafficDelay: Double // seconds of delay due to traffic
    let geometry: RouteGeometry?
    let incidents: [TrafficIncident]
    let alternativeRoutes: [AlternativeRoute]
    let congestionLevel: CongestionLevel
    
    var distanceInMiles: Double {
        distance * 0.000621371
    }
    
    var distanceInKilometers: Double {
        distance / 1000.0
    }
    
    var durationInMinutes: Double {
        duration / 60.0
    }
    
    var totalDurationWithTraffic: Double {
        duration + trafficDelay
    }
    
    var trafficDelayMinutes: Double {
        trafficDelay / 60.0
    }
}

struct RouteGeometry: Codable, Equatable {
    let coordinates: [[Double]] // [longitude, latitude] pairs
    let type: String // "LineString"
}

struct TrafficIncident: Codable, Equatable, Identifiable {
    let id: String
    let type: IncidentType
    let description: String
    let severity: Int // 0-4, higher is more severe
    let coordinate: Coordinate
    let startTime: Date?
    let estimatedClearTime: Date?
    
    var severityLevel: String {
        switch severity {
        case 0: return "Minor"
        case 1: return "Moderate"
        case 2: return "Major"
        case 3: return "Serious"
        case 4: return "Critical"
        default: return "Unknown"
        }
    }
}

enum IncidentType: String, Codable {
    case accident
    case roadClosure
    case construction
    case congestion
    case weatherCondition
    case other
}

enum CongestionLevel: Int, Codable {
    case none = 0
    case low = 1
    case moderate = 2
    case heavy = 3
    case severe = 4
    
    var description: String {
        switch self {
        case .none: return "Clear"
        case .low: return "Light Traffic"
        case .moderate: return "Moderate Traffic"
        case .heavy: return "Heavy Traffic"
        case .severe: return "Severe Traffic"
        }
    }
    
    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "yellow"
        case .moderate: return "orange"
        case .heavy: return "red"
        case .severe: return "darkRed"
        }
    }
}

struct AlternativeRoute: Codable, Equatable, Identifiable {
    let id: String
    let distance: Double
    let duration: Double
    let trafficDelay: Double
    let routeName: String?
    let geometry: RouteGeometry?
    
    var durationInMinutes: Double {
        duration / 60.0
    }
    
    var totalDurationWithTraffic: Double {
        duration + trafficDelay
    }
}

