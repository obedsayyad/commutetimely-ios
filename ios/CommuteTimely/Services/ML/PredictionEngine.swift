//
//  PredictionEngine.swift
//  CommuteTimely
//
//  Coordinates traffic/weather snapshots with ML predictions and fallbacks.
//

import Foundation

protocol PredictionEngineProtocol {
    func recommendation(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date
    ) async -> LeaveTimeRecommendation
}

struct LeaveTimeRecommendation {
    let prediction: Prediction
    let snapshot: TrafficWeatherSnapshot
    let source: PredictionSource
    let recommendedLeaveTimeUtc: Date
    let explanation: String
    let weatherPenaltyMinutes: Int
    let userBufferMinutes: Int
}

final class PredictionEngine: PredictionEngineProtocol {
    private let trafficWeatherService: TrafficWeatherMergeServiceProtocol
    private let mlService: MLPredictionServiceProtocol
    private let userPreferencesService: UserPreferencesServiceProtocol
    
    init(
        trafficWeatherService: TrafficWeatherMergeServiceProtocol,
        mlService: MLPredictionServiceProtocol,
        userPreferencesService: UserPreferencesServiceProtocol
    ) {
        self.trafficWeatherService = trafficWeatherService
        self.mlService = mlService
        self.userPreferencesService = userPreferencesService
    }
    
    func recommendation(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date
    ) async -> LeaveTimeRecommendation {
        let snapshot: TrafficWeatherSnapshot
        do {
            snapshot = try await trafficWeatherService.snapshot(
                origin: origin,
                destination: destination,
                arrivalTime: arrivalTime
            )
        } catch {
            snapshot = TrafficWeatherSnapshot(
                route: RouteInfo(
                    distance: 12000,
                    duration: 900,
                    trafficDelay: 120,
                    geometry: nil,
                    incidents: [],
                    alternativeRoutes: [],
                    congestionLevel: .moderate
                ),
                weather: WeatherData(
                    temperature: 21,
                    feelsLike: 21,
                    conditions: .partlyCloudy,
                    precipitation: 0,
                    precipitationProbability: 10,
                    windSpeed: 4,
                    windDirection: 180,
                    visibility: 10,
                    humidity: 55,
                    pressure: 1012,
                    uvIndex: 4,
                    cloudCoverage: 20,
                    timestamp: Date(),
                    alerts: []
                ),
                heuristicsDelay: 120,
                generatedAt: Date(),
                explanation: "Using cached heuristics",
                confidence: 0.6
            )
        }
        
        let prediction: Prediction
        do {
            prediction = try await mlService.predict(
                origin: origin,
                destination: destination,
                arrivalTime: arrivalTime,
                routeInfo: snapshot.route,
                weather: snapshot.weather
            )
        } catch {
            prediction = heuristicPrediction(
                snapshot: snapshot,
                arrivalTime: arrivalTime
            )
        }
        
        // Get user preferences for buffer
        let preferences = await userPreferencesService.loadPreferences()
        let userBufferMinutes = preferences.notificationSettings.defaultReminderOffsets.first ?? 10
        
        // Calculate weather penalty in minutes
        let weatherPenaltyMinutes = Int(snapshot.leaveTimeAdjustment / 60)
        
        // Calculate final recommended leave time with user buffer
        let baseTravelTime = snapshot.route.totalDurationWithTraffic
        let weatherAdjustment = snapshot.leaveTimeAdjustment
        let userBufferSeconds = Double(userBufferMinutes * 60)
        let totalTravelTime = baseTravelTime + weatherAdjustment + userBufferSeconds
        
        let recommendedLeaveTimeUtc = arrivalTime.addingTimeInterval(-totalTravelTime)
        
        // Build explanation
        let explanation = buildExplanation(
            snapshot: snapshot,
            weatherPenalty: weatherPenaltyMinutes,
            userBuffer: userBufferMinutes,
            recommendedLeaveTime: recommendedLeaveTimeUtc
        )
        
        log(snapshot, prediction: prediction)
        
        return LeaveTimeRecommendation(
            prediction: prediction,
            snapshot: snapshot,
            source: prediction.predictionSource,
            recommendedLeaveTimeUtc: recommendedLeaveTimeUtc,
            explanation: explanation,
            weatherPenaltyMinutes: weatherPenaltyMinutes,
            userBufferMinutes: userBufferMinutes
        )
    }
    
    private func buildExplanation(
        snapshot: TrafficWeatherSnapshot,
        weatherPenalty: Int,
        userBuffer: Int,
        recommendedLeaveTime: Date
    ) -> String {
        var parts: [String] = []
        
        // Base travel time
        let travelMinutes = Int(snapshot.route.totalDurationWithTraffic / 60)
        parts.append("\(travelMinutes) min travel time")
        
        // Traffic condition
        if snapshot.route.congestionLevel != .none && snapshot.route.congestionLevel != .low {
            parts.append(snapshot.route.congestionLevel.description.lowercased())
        }
        
        // Weather impact
        if weatherPenalty > 0 {
            parts.append("\(weatherPenalty) min weather delay")
        }
        
        // User buffer
        if userBuffer > 0 {
            parts.append("\(userBuffer) min buffer")
        }
        
        // Format leave time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let leaveTimeStr = formatter.string(from: recommendedLeaveTime)
        parts.append("Leave by \(leaveTimeStr)")
        
        return parts.joined(separator: " • ")
    }
    
    private func log(_ snapshot: TrafficWeatherSnapshot, prediction: Prediction) {
        guard AppConfiguration.isPredictionVerboseLoggingEnabled else { return }
        print("""
        [PredictionEngine]
        Route: \(Int(snapshot.route.distanceInMiles)) mi, traffic \(snapshot.route.congestionLevel)
        Weather: \(snapshot.weather.conditions.description), \(Int(snapshot.weather.temperature))°
        Leave at: \(prediction.leaveTime) (confidence \(Int(prediction.confidence * 100))%)
        Explanation: \(prediction.explanation)
        """)
    }
    
    private func heuristicPrediction(
        snapshot: TrafficWeatherSnapshot,
        arrivalTime: Date
    ) -> Prediction {
        let travelTime = snapshot.route.totalDurationWithTraffic + snapshot.leaveTimeAdjustment
        let leaveTime = arrivalTime.addingTimeInterval(-travelTime)
        let bufferMinutes = Int(max(5, snapshot.leaveTimeAdjustment / 60))
        let explanation = snapshot.explanation
        
        return Prediction(
            leaveTime: leaveTime,
            confidence: snapshot.confidence,
            explanation: explanation,
            alternativeLeaveTimes: [
                AlternativeLeaveTime(
                    leaveTime: leaveTime.addingTimeInterval(-600),
                    arrivalProbability: 0.92,
                    description: "Leave 10 min earlier for extra buffer"
                ),
                AlternativeLeaveTime(
                    leaveTime: leaveTime.addingTimeInterval(300),
                    arrivalProbability: 0.65,
                    description: "Cutting it close"
                )
            ],
            bufferMinutes: bufferMinutes,
            predictionSource: .coreML,
            predictedAt: Date()
        )
    }
}

