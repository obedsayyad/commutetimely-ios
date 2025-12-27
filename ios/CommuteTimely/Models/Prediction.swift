//
// Prediction.swift
// CommuteTimely
//
// ML prediction models for leave time recommendations
//

import Foundation

struct Prediction: Codable, Equatable {
    let leaveTime: Date
    let confidence: Double // 0.0 to 1.0
    let explanation: String
    let alternativeLeaveTimes: [AlternativeLeaveTime]
    let bufferMinutes: Int
    let predictionSource: PredictionSource
    let predictedAt: Date
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
    
    var isMediumConfidence: Bool {
        confidence >= 0.6 && confidence < 0.8
    }
    
    var isLowConfidence: Bool {
        confidence < 0.6
    }
}

struct AlternativeLeaveTime: Codable, Equatable, Identifiable {
    let id: UUID
    let leaveTime: Date
    let arrivalProbability: Double
    let description: String
    
    init(
        id: UUID = UUID(),
        leaveTime: Date,
        arrivalProbability: Double,
        description: String
    ) {
        self.id = id
        self.leaveTime = leaveTime
        self.arrivalProbability = arrivalProbability
        self.description = description
    }
}

enum PredictionSource: String, Codable {
    case server
    case coreML
    case cached
    
    var displayName: String {
        switch self {
        case .server: return "Live Prediction"
        case .coreML: return "Offline Prediction"
        case .cached: return "Cached Prediction"
        }
    }
}

// MARK: - Prediction Request/Response DTOs

struct PredictionRequest: Codable {
    let origin: Coordinate
    let destination: Coordinate
    let arrivalTime: Date
    let currentTime: Date
    let routeFeatures: RouteFeatures
    let weatherFeatures: WeatherFeatures
    let userFeatures: UserFeatures?
    
    struct RouteFeatures: Codable {
        let distance: Double
        let baselineDuration: Double
        let currentTrafficDelay: Double
        let incidentCount: Int
        let congestionLevel: Int
    }
    
    struct WeatherFeatures: Codable {
        let temperature: Double
        let precipitation: Double
        let precipitationProbability: Double
        let windSpeed: Double
        let visibility: Double
        let weatherScore: Double
    }
    
    struct UserFeatures: Codable {
        let userId: String
        let historicalVariance: Double?
        let preferredBuffer: Int
    }
}

struct PredictionResponse: Codable {
    let leaveTime: Date
    let confidence: Double
    let explanation: String
    let alternativeLeaveTimes: [AlternativeLeaveTimeDTO]
    let bufferMinutes: Int
    let calculatedAt: Date
    
    struct AlternativeLeaveTimeDTO: Codable {
        let leaveTime: Date
        let arrivalProbability: Double
        let description: String
    }
    
    func toPrediction() -> Prediction {
        Prediction(
            leaveTime: leaveTime,
            confidence: confidence,
            explanation: explanation,
            alternativeLeaveTimes: alternativeLeaveTimes.map { alt in
                AlternativeLeaveTime(
                    leaveTime: alt.leaveTime,
                    arrivalProbability: alt.arrivalProbability,
                    description: alt.description
                )
            },
            bufferMinutes: bufferMinutes,
            predictionSource: .server,
            predictedAt: calculatedAt
        )
    }
}

