//
//  SearchServiceTests.swift
//  CommuteTimelyTests
//

import XCTest
@testable import CommuteTimely

final class SearchServiceTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var userDefaultsSuite: String!
    private var tripStorage: MockTripStorageService!
    private var sut: SearchService!
    
    override func setUp() {
        super.setUp()
        userDefaultsSuite = "SearchServiceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: userDefaultsSuite)
        tripStorage = MockTripStorageService()
        sut = SearchService(
            mapboxService: MockMapboxService(),
            tripStorageService: tripStorage,
            userDefaults: userDefaults
        )
    }
    
    override func tearDown() {
        userDefaults?.removePersistentDomain(forName: userDefaultsSuite)
        userDefaults = nil
        userDefaultsSuite = nil
        tripStorage = nil
        sut = nil
        super.tearDown()
    }
    
    func testRecentsSurfaceFirst() async throws {
        let location = Location(
            coordinate: Coordinate(latitude: 37.3, longitude: -122.0),
            address: "123 Test St",
            placeName: "Test Cafe"
        )
        sut.recordSelection(location)
        
        let response = try await sut.suggestions(for: "Test", userCoordinate: nil)
        XCTAssertTrue(response.suggestions.contains(where: { $0.source == .recent }))
    }
    
    func testFavoritesIncludedWhenTagged() async throws {
        var trip = Trip(
            destination: Location(
                coordinate: Coordinate(latitude: 37.1, longitude: -121.9),
                address: "456 Folsom",
                placeName: "Home Base",
                placeType: .home
            ),
            arrivalTime: Date().addingTimeInterval(3600),
            bufferMinutes: 10
        )
        trip.tags = [.home]
        try await tripStorage.saveTrip(trip)
        
        let response = try await sut.suggestions(for: "", userCoordinate: nil)
        XCTAssertTrue(response.suggestions.contains(where: { $0.source == .favorite }))
    }
}

