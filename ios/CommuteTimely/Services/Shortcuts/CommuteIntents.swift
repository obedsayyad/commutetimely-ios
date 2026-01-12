//
// CommuteIntents.swift
// CommuteTimely
//
// App Intents for Siri and Shortcuts integration
//

import AppIntents
import SwiftUI

struct NextCommuteIntent: AppIntent {
    static var title: LocalizedStringResource = "When should I leave?"
    static var description = IntentDescription("Calculates and tells you when to leave for your next scheduled trip.")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let storage = DIContainer.shared.tripStorageService
        let scheduler = DIContainer.shared.leaveTimeScheduler
        
        let trips = try await storage.fetchTrips()
        guard let nextTrip = trips.filter({ $0.isActive }).sorted(by: { $0.arrivalTime < $1.arrivalTime }).first else {
            return .result(
                value: "No upcoming trips found.",
                dialog: "You don't have any upcoming trips scheduled in CommuteTimely."
            )
        }
        
        // This is a simplified calculation for the intent
        // In a full implementation, we'd fetch a fresh prediction here
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let arrivalStr = formatter.string(from: nextTrip.arrivalTime)
        return .result(
            value: "Your next trip to \(nextTrip.destination.displayName) is at \(arrivalStr).",
            dialog: "Your next trip to \(nextTrip.destination.displayName) is scheduled for \(arrivalStr). I'll alert you when it's time to head out."
        )
    }
}

struct CommuteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextCommuteIntent(),
            phrases: [
                "When should I leave with \(.applicationName)?",
                "Check my next commute with \(.applicationName)",
                "\(.applicationName) next trip"
            ],
            shortTitle: "Next Commute",
            systemImageName: "car.fill"
        )
    }
}
