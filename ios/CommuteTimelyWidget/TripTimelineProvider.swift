//
// TripTimelineProvider.swift
// CommuteTimelyWidget
//
// Timeline provider for fetching and updating trip data
//

import WidgetKit
import Foundation

struct TripTimelineEntry: TimelineEntry {
    let date: Date
    let nextTrip: TripEntry?
    let error: String?
}

struct TripEntry: Codable {
    let id: UUID
    let destinationName: String
    let arrivalTime: Date
    let leaveTime: Date?
    let travelTimeMinutes: Int?
    let isActive: Bool
}

struct TripTimelineProvider: TimelineProvider {
    typealias Entry = TripTimelineEntry
    
    // App Group identifier - must match the one configured in Xcode
    private let appGroupIdentifier = "group.com.commutetimely.shared"
    
    func placeholder(in context: Context) -> Entry {
        TripTimelineEntry(
            date: Date(),
            nextTrip: TripEntry(
                id: UUID(),
                destinationName: "Work",
                arrivalTime: Date().addingTimeInterval(3600),
                leaveTime: Date().addingTimeInterval(3300),
                travelTimeMinutes: 30,
                isActive: true
            ),
            error: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let entry = loadNextTrip()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = loadNextTrip()
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadNextTrip() -> Entry {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return TripTimelineEntry(
                date: Date(),
                nextTrip: nil,
                error: "Unable to access shared data"
            )
        }
        
        // Load trips from App Group UserDefaults
        guard let tripsData = sharedDefaults.data(forKey: "sharedTrips"),
              let trips = try? JSONDecoder().decode([WidgetTripData].self, from: tripsData) else {
            return TripTimelineEntry(
                date: Date(),
                nextTrip: nil,
                error: nil
            )
        }
        
        // Find the next active trip
        let now = Date()
        let activeTrips = trips.filter { $0.isActive }
        let upcomingTrips = activeTrips.filter { $0.arrivalTime > now }
            .sorted { $0.arrivalTime < $1.arrivalTime }
        
        guard let nextTripData = upcomingTrips.first else {
            return TripTimelineEntry(
                date: Date(),
                nextTrip: nil,
                error: nil
            )
        }
        
        // Calculate leave time if we have travel time
        let leaveTime: Date?
        if let travelTime = nextTripData.travelTimeMinutes {
            leaveTime = nextTripData.arrivalTime.addingTimeInterval(-Double(travelTime * 60))
                .addingTimeInterval(-Double(nextTripData.bufferMinutes * 60))
        } else {
            leaveTime = nil
        }
        
        let tripEntry = TripEntry(
            id: nextTripData.id,
            destinationName: nextTripData.destinationName,
            arrivalTime: nextTripData.arrivalTime,
            leaveTime: leaveTime,
            travelTimeMinutes: nextTripData.travelTimeMinutes,
            isActive: nextTripData.isActive
        )
        
        return TripTimelineEntry(
            date: Date(),
            nextTrip: tripEntry,
            error: nil
        )
    }
}

// Simplified Trip data structure for widget sharing (must match WidgetTripData in TripStorageService)
struct WidgetTripData: Codable {
    let id: UUID
    let destinationName: String
    let arrivalTime: Date
    let bufferMinutes: Int
    let isActive: Bool
    let travelTimeMinutes: Int?
}

