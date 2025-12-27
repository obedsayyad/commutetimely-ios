//
// MLPredictionService.swift
// CommuteTimely
//
// ML prediction service with server and CoreML fallback
//

import Foundation
import CoreML

protocol MLPredictionServiceProtocol {
    func predict(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date,
        routeInfo: RouteInfo,
        weather: WeatherData
    ) async throws -> Prediction
}

class MLPredictionService: MLPredictionServiceProtocol {
    private let networkService: NetworkServiceProtocol
    private let serverURL: String
    private var coreMLModel: MLModel?
    
    init(networkService: NetworkServiceProtocol, serverURL: String) {
        self.networkService = networkService
        self.serverURL = serverURL
        loadCoreMLModel()
    }
    
    func predict(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date,
        routeInfo: RouteInfo,
        weather: WeatherData
    ) async throws -> Prediction {
        // Try server prediction first (only if auth is available)
        do {
            return try await predictFromServer(
                origin: origin,
                destination: destination,
                arrivalTime: arrivalTime,
                routeInfo: routeInfo,
                weather: weather
            )
        } catch let error as NetworkError {
            // For auth errors, silently fall back to CoreML (no error message)
            if case .unauthorized = error {
                // Silently fall back to CoreML - this is expected when user is not authenticated
                return try await predictFromCoreML(
                    origin: origin,
                    destination: destination,
                    arrivalTime: arrivalTime,
                    routeInfo: routeInfo,
                    weather: weather
                )
            }
            // For other network errors, log and fall back
            print("[ML] Server prediction failed: \(error.localizedDescription). Falling back to CoreML...")
            return try await predictFromCoreML(
                origin: origin,
                destination: destination,
                arrivalTime: arrivalTime,
                routeInfo: routeInfo,
                weather: weather
            )
        } catch {
            // For any other errors, log and fall back to CoreML
            print("[ML] Server prediction failed: \(error.localizedDescription). Falling back to CoreML...")
            return try await predictFromCoreML(
                origin: origin,
                destination: destination,
                arrivalTime: arrivalTime,
                routeInfo: routeInfo,
                weather: weather
            )
        }
    }
    
    private func predictFromServer(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date,
        routeInfo: RouteInfo,
        weather: WeatherData
    ) async throws -> Prediction {
        let request = PredictionRequest(
            origin: origin,
            destination: destination,
            arrivalTime: arrivalTime,
            currentTime: Date(),
            routeFeatures: PredictionRequest.RouteFeatures(
                distance: routeInfo.distance,
                baselineDuration: routeInfo.duration,
                currentTrafficDelay: routeInfo.trafficDelay,
                incidentCount: routeInfo.incidents.count,
                congestionLevel: routeInfo.congestionLevel.rawValue
            ),
            weatherFeatures: PredictionRequest.WeatherFeatures(
                temperature: weather.temperature,
                precipitation: weather.precipitation,
                precipitationProbability: weather.precipitationProbability,
                windSpeed: weather.windSpeed,
                visibility: weather.visibility,
                weatherScore: weather.weatherScore
            ),
            userFeatures: nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)
        
        let endpoint = Endpoint(
            baseURL: serverURL,
            path: "/predict",
            method: .post,
            body: body,
            requiresAuth: true
        )
        
        let response: PredictionResponse = try await networkService.request(endpoint)
        return response.toPrediction()
    }
    
    private func predictFromCoreML(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date,
        routeInfo: RouteInfo,
        weather: WeatherData
    ) async throws -> Prediction {
        // Simple heuristic-based prediction when CoreML model isn't available
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: arrivalTime)
        let dayOfWeek = calendar.component(.weekday, from: arrivalTime)
        
        // Base travel time
        var travelTime = routeInfo.duration + routeInfo.trafficDelay
        
        // Weather adjustment
        travelTime *= weather.conditions.impactOnTravel.delayMultiplier
        
        // Rush hour adjustment
        if (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19) {
            travelTime *= 1.25
        }
        
        // Weekend adjustment
        if dayOfWeek == 1 || dayOfWeek == 7 {
            travelTime *= 0.9
        }
        
        // Add buffer (15% of travel time, min 5 minutes, max 20 minutes)
        let bufferMinutes = max(5, min(20, Int(travelTime / 60 * 0.15)))
        
        // Calculate leave time
        let totalTimeNeeded = travelTime + Double(bufferMinutes * 60)
        let leaveTime = arrivalTime.addingTimeInterval(-totalTimeNeeded)
        
        // Confidence based on data freshness and conditions
        var confidence = 0.75
        
        // Lower confidence for bad weather
        if weather.conditions.impactOnTravel == .major || weather.conditions.impactOnTravel == .severe {
            confidence -= 0.15
        }
        
        // Lower confidence for heavy traffic
        if routeInfo.congestionLevel == .heavy || routeInfo.congestionLevel == .severe {
            confidence -= 0.1
        }
        
        let explanation = generateExplanation(
            travelTime: travelTime,
            weather: weather,
            congestion: routeInfo.congestionLevel,
            bufferMinutes: bufferMinutes
        )
        
        // Generate alternative leave times
        let alternatives = [
            AlternativeLeaveTime(
                leaveTime: leaveTime.addingTimeInterval(-600), // 10 min earlier
                arrivalProbability: 0.95,
                description: "Extra safe: arrive 10 minutes early"
            ),
            AlternativeLeaveTime(
                leaveTime: leaveTime.addingTimeInterval(300), // 5 min later
                arrivalProbability: 0.65,
                description: "Risky: might arrive 5 minutes late"
            )
        ]
        
        return Prediction(
            leaveTime: leaveTime,
            confidence: confidence,
            explanation: explanation,
            alternativeLeaveTimes: alternatives,
            bufferMinutes: bufferMinutes,
            predictionSource: .coreML,
            predictedAt: Date()
        )
    }
    
    private func generateExplanation(
        travelTime: Double,
        weather: WeatherData,
        congestion: CongestionLevel,
        bufferMinutes: Int
    ) -> String {
        let travelMinutes = Int(travelTime / 60)
        var parts: [String] = []
        
        parts.append("\(travelMinutes) min travel time")
        
        if congestion.rawValue >= 2 {
            parts.append(congestion.description.lowercased())
        }
        
        let impact = weather.conditions.impactOnTravel
        if impact == .moderate || impact == .major || impact == .severe {
            parts.append(weather.conditions.description.lowercased())
        }
        
        parts.append("\(bufferMinutes) min buffer")
        
        return parts.joined(separator: ", ")
    }
    
    private func loadCoreMLModel() {
        // In a real implementation, load the CoreML model
        // guard let modelURL = Bundle.main.url(forResource: "LeaveTimePredictor", withExtension: "mlmodelc") else { return }
        // self.coreMLModel = try? MLModel(contentsOf: modelURL)
    }
}

// MARK: - Mock Service

class MockMLPredictionService: MLPredictionServiceProtocol {
    func predict(
        origin: Coordinate,
        destination: Coordinate,
        arrivalTime: Date,
        routeInfo: RouteInfo,
        weather: WeatherData
    ) async throws -> Prediction {
        try await Task.sleep(nanoseconds: 800_000_000)
        
        let travelTime = routeInfo.duration + routeInfo.trafficDelay
        let bufferMinutes = 15
        let leaveTime = arrivalTime.addingTimeInterval(-(travelTime + Double(bufferMinutes * 60)))
        
        return Prediction(
            leaveTime: leaveTime,
            confidence: 0.85,
            explanation: "20 min travel, moderate traffic, 15 min buffer",
            alternativeLeaveTimes: [
                AlternativeLeaveTime(
                    leaveTime: leaveTime.addingTimeInterval(-600),
                    arrivalProbability: 0.95,
                    description: "Leave 10 min earlier for safety"
                )
            ],
            bufferMinutes: bufferMinutes,
            predictionSource: .server,
            predictedAt: Date()
        )
    }
}

