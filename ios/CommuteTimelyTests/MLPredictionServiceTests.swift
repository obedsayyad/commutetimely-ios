//
// MLPredictionServiceTests.swift
// CommuteTimelyTests
//
// Unit tests for ML Prediction Service
//

import XCTest
@testable import CommuteTimely

final class MLPredictionServiceTests: XCTestCase {
    var sut: MockMLPredictionService!
    
    override func setUp() {
        super.setUp()
        sut = MockMLPredictionService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testPredictReturnsValidPrediction() async throws {
        // Given
        let origin = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let destination = Coordinate(latitude: 37.8044, longitude: -122.2712)
        let arrivalTime = Date().addingTimeInterval(3600)
        let routeInfo = createMockRouteInfo()
        let weather = createMockWeather()
        
        // When
        let prediction = try await sut.predict(
            origin: origin,
            destination: destination,
            arrivalTime: arrivalTime,
            routeInfo: routeInfo,
            weather: weather
        )
        
        // Then
        XCTAssertNotNil(prediction)
        XCTAssertTrue(prediction.leaveTime < arrivalTime)
        XCTAssertGreaterThan(prediction.confidence, 0.0)
        XCTAssertLessThanOrEqual(prediction.confidence, 1.0)
    }
    
    func testPredictionLeaveTimeIsBeforeArrival() async throws {
        // Given
        let origin = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let destination = Coordinate(latitude: 37.8044, longitude: -122.2712)
        let arrivalTime = Date().addingTimeInterval(3600)
        let routeInfo = createMockRouteInfo()
        let weather = createMockWeather()
        
        // When
        let prediction = try await sut.predict(
            origin: origin,
            destination: destination,
            arrivalTime: arrivalTime,
            routeInfo: routeInfo,
            weather: weather
        )
        
        // Then
        XCTAssertLessThan(prediction.leaveTime, arrivalTime)
        
        // Leave time should be reasonable (not too far in past)
        let minutesBeforeArrival = arrivalTime.timeIntervalSince(prediction.leaveTime) / 60
        XCTAssertGreaterThan(minutesBeforeArrival, 10) // At least 10 minutes
        XCTAssertLessThan(minutesBeforeArrival, 120) // Not more than 2 hours
    }
    
    func testConfidenceScoreIsValid() async throws {
        // Given
        let origin = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let destination = Coordinate(latitude: 37.8044, longitude: -122.2712)
        let arrivalTime = Date().addingTimeInterval(3600)
        let routeInfo = createMockRouteInfo()
        let weather = createMockWeather()
        
        // When
        let prediction = try await sut.predict(
            origin: origin,
            destination: destination,
            arrivalTime: arrivalTime,
            routeInfo: routeInfo,
            weather: weather
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(prediction.confidence, 0.0)
        XCTAssertLessThanOrEqual(prediction.confidence, 1.0)
    }
    
    // MARK: - Helpers
    
    private func createMockRouteInfo() -> RouteInfo {
        RouteInfo(
            distance: 15000,
            duration: 1200,
            trafficDelay: 180,
            geometry: nil,
            incidents: [],
            alternativeRoutes: [],
            congestionLevel: .moderate
        )
    }
    
    private func createMockWeather() -> WeatherData {
        WeatherData(
            temperature: 22.0,
            feelsLike: 21.0,
            conditions: .partlyCloudy,
            precipitation: 0.0,
            precipitationProbability: 20.0,
            windSpeed: 5.5,
            windDirection: 180,
            visibility: 10.0,
            humidity: 65,
            pressure: 1013.25,
            uvIndex: 5,
            cloudCoverage: 40,
            timestamp: Date(),
            alerts: []
        )
    }
}

