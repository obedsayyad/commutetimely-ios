//
//  DestinationStoreTests.swift
//  CommuteTimelyTests
//

import XCTest
import CoreData
@testable import CommuteTimely

final class DestinationStoreTests: XCTestCase {
    func testSaveAndFetchTrip() async throws {
        let store = CoreDataDestinationStore(storeURL: nil, storeType: NSInMemoryStoreType)
        let trip = Trip(
            destination: Location(
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                address: "1 Market St",
                placeName: "HQ"
            ),
            arrivalTime: Date().addingTimeInterval(3600),
            bufferMinutes: 15,
            tags: [.work]
        )
        
        try await store.saveTrip(trip)
        let fetched = try await store.fetchTrips()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.destination.address, "1 Market St")
        XCTAssertTrue(fetched.first?.tags.contains(.work) ?? false)
    }
}

