//
//  PredictionEngineTests.swift
//  CommuteTimelyTests
//

import XCTest
@testable import CommuteTimely

final class PredictionEngineTests: XCTestCase {
    func testFallbackPredictionWhenMLFails() async {
        let trafficWeather = MockTrafficWeatherMergeService()
        let mlService = FailingMLService()
        let preferences = MockUserPreferencesService()
        
        let engine = PredictionEngine(
            trafficWeatherService: trafficWeather,
            mlService: mlService,
            userPreferencesService: preferences
        )
        
        let recommendation = await engine.recommendation(
            origin: Coordinate(latitude: 37.0, longitude: -122.0),
            destination: Coordinate(latitude: 37.1, longitude: -122.1),
            arrivalTime: Date().addingTimeInterval(3600)
        )
        
        XCTAssertLessThan(recommendation.prediction.confidence, 0.9)
        XCTAssertEqual(recommendation.prediction.predictionSource, .coreML)
        XCTAssertGreaterThan(recommendation.prediction.bufferMinutes, 0)
    }
    
    private final class FailingMLService: MLPredictionServiceProtocol {
        func predict(
            origin: Coordinate,
            destination: Coordinate,
            arrivalTime: Date,
            routeInfo: RouteInfo,
            weather: WeatherData
        ) async throws -> Prediction {
            throw NetworkError.serverError(500)
        }
    }
}

