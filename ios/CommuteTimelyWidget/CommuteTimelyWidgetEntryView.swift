//
// CommuteTimelyWidgetEntryView.swift
// CommuteTimelyWidget
//
// Widget entry view that displays different layouts based on widget family
//

import WidgetKit
import SwiftUI

struct CommuteTimelyWidgetEntryView: View {
    var entry: TripTimelineEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)

struct SmallWidgetView: View {
    var entry: TripTimelineEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trip = entry.nextTrip {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Spacer()
                }
                
                Text(trip.destinationName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                if let leaveTime = trip.leaveTime {
                    Text(timeUntilLeave(leaveTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatTime(trip.arrivalTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = entry.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack {
                    Image(systemName: "map")
                        .foregroundColor(.secondary)
                    Text("No upcoming trips")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func timeUntilLeave(_ leaveTime: Date) -> String {
        let now = Date()
        let timeInterval = leaveTime.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Leave now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Leave in \(minutes)m"
        } else {
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "Leave in \(hours)h \(minutes)m"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Medium Widget (4x2)

struct MediumWidgetView: View {
    var entry: TripTimelineEntry
    
    var body: some View {
        HStack(spacing: 16) {
            if let trip = entry.nextTrip {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text(trip.destinationName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    
                    if let leaveTime = trip.leaveTime {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Leave by")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(leaveTime))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arrive by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(trip.arrivalTime))
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let travelTime = trip.travelTimeMinutes {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(travelTime) min")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("travel time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let leaveTime = trip.leaveTime {
                        Text(timeUntilLeave(leaveTime))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                EmptyStateView(message: entry.error ?? "No upcoming trips")
            }
        }
        .padding()
    }
    
    private func timeUntilLeave(_ leaveTime: Date) -> String {
        let now = Date()
        let timeInterval = leaveTime.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Leave now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Large Widget (4x4)

struct LargeWidgetView: View {
    var entry: TripTimelineEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let trip = entry.nextTrip {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                    Text(trip.destinationName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                Divider()
                
                if let leaveTime = trip.leaveTime {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Leave by")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(leaveTime))
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(timeUntilLeave(leaveTime))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text("until leave")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Arrive by")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(trip.arrivalTime))
                                    .font(.headline)
                            }
                            
                            if let travelTime = trip.travelTimeMinutes {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Travel time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(travelTime) min")
                                        .font(.headline)
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arrive by")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(trip.arrivalTime))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        if let travelTime = trip.travelTimeMinutes {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Travel time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(travelTime) min")
                                    .font(.headline)
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(message: entry.error ?? "No upcoming trips")
            }
        }
        .padding()
    }
    
    private func timeUntilLeave(_ leaveTime: Date) -> String {
        let now = Date()
        let timeInterval = leaveTime.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

