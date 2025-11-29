//
// TripStorageServiceTests.swift
// CommuteTimelyTests
//
// Unit tests for TripStorageService
//

import XCTest
import Combine
@testable import CommuteTimely

final class TripStorageServiceTests: XCTestCase {
    var sut: MockTripStorageService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = MockTripStorageService()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }
    
    func testSaveTripAddsToStorage() async throws {
        // Given
        let trip = createSampleTrip()
        let expectation = XCTestExpectation(description: "Trip saved")
        
        // When
        try await sut.saveTrip(trip)
        
        // Then
        sut.trips
            .sink { trips in
                XCTAssertTrue(trips.contains(where: { $0.id == trip.id }))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchTripReturnsCorrectTrip() async throws {
        // Given
        let trip = createSampleTrip()
        try await sut.saveTrip(trip)
        
        // When
        let fetchedTrip = await sut.fetchTrip(id: trip.id)
        
        // Then
        XCTAssertNotNil(fetchedTrip)
        XCTAssertEqual(fetchedTrip?.id, trip.id)
        XCTAssertEqual(fetchedTrip?.destination.displayName, trip.destination.displayName)
    }
    
    func testUpdateTripModifiesExisting() async throws {
        // Given
        var trip = createSampleTrip()
        try await sut.saveTrip(trip)
        
        // When
        trip.bufferMinutes = 20
        try await sut.updateTrip(trip)
        
        // Then
        let updated = await sut.fetchTrip(id: trip.id)
        XCTAssertEqual(updated?.bufferMinutes, 20)
    }
    
    func testDeleteTripRemovesFromStorage() async throws {
        // Given
        let trip = createSampleTrip()
        try await sut.saveTrip(trip)
        
        // When
        try await sut.deleteTrip(id: trip.id)
        
        // Then
        let fetchedTrip = await sut.fetchTrip(id: trip.id)
        XCTAssertNil(fetchedTrip)
    }
    
    // MARK: - Helpers
    
    private func createSampleTrip() -> Trip {
        Trip(
            destination: Location(
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                address: "123 Main St, San Francisco, CA",
                placeName: "Office"
            ),
            arrivalTime: Date().addingTimeInterval(3600),
            bufferMinutes: 15
        )
    }
}

