//
// LocationServiceTests.swift
// CommuteTimelyTests
//
// Unit tests for LocationService
//

import XCTest
import CoreLocation
import Combine
@testable import CommuteTimely

final class LocationServiceTests: XCTestCase {
    var sut: MockLocationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = MockLocationService()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }
    
    func testCurrentLocationPublished() {
        // Given
        let expectation = XCTestExpectation(description: "Current location published")
        var receivedLocation: CLLocation?
        
        // When
        sut.currentLocation
            .sink { location in
                receivedLocation = location
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedLocation)
        XCTAssertEqual(receivedLocation?.coordinate.latitude, 37.7749, accuracy: 0.001)
    }
    
    func testGeocodeReturnsLocations() async throws {
        // Given
        let query = "San Francisco"
        
        // When
        let locations = try await sut.geocode(address: query)
        
        // Then
        XCTAssertFalse(locations.isEmpty)
        XCTAssertEqual(locations.first?.placeName, "Mock Location")
    }
    
    func testReverseGeocodeReturnsAddress() async throws {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When
        let location = try await sut.reverseGeocode(coordinate: coordinate)
        
        // Then
        XCTAssertEqual(location.address, "123 Mock St, San Francisco, CA")
    }
}

