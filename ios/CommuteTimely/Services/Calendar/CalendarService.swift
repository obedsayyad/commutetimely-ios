//
// CalendarService.swift
// CommuteTimely
//
// Service for fetching and processing iOS Calendar events for trip suggestions
//

import Foundation
import EventKit
import Combine

struct CalendarEventSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

protocol CalendarServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEventSuggestion]
}

class CalendarService: CalendarServiceProtocol {
    private let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    func fetchUpcomingEvents(days: Int = 7) async throws -> [CalendarEventSuggestion] {
        let calendars = eventStore.calendars(for: .event)
        
        // Use local time for range
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        return events
            .filter { $0.location != nil && !($0.location?.isEmpty ?? true) }
            .map { event in
                CalendarEventSuggestion(
                    id: event.eventIdentifier,
                    title: event.title,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay
                )
            }
            .sorted(by: { $0.startDate < $1.startDate })
    }
}

// MARK: - Mock Service
class MockCalendarService: CalendarServiceProtocol {
    func requestAccess() async throws -> Bool {
        return true
    }
    
    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEventSuggestion] {
        return [
            CalendarEventSuggestion(
                id: "1",
                title: "Work Meeting",
                location: "Infinite Loop, Cupertino",
                startDate: Date().addingTimeInterval(3600),
                endDate: Date().addingTimeInterval(7200),
                isAllDay: false
            ),
            CalendarEventSuggestion(
                id: "2",
                title: "Gym Session",
                location: "24 Hour Fitness, San Jose",
                startDate: Date().addingTimeInterval(86400),
                endDate: Date().addingTimeInterval(90000),
                isAllDay: false
            )
        ]
    }
}
