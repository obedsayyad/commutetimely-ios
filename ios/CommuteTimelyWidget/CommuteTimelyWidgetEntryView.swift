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
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                if let trip = entry.nextTrip {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                        if let travelTime = trip.travelTimeMinutes {
                            Text("\(travelTime)m")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Trip")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(trip.destinationName)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                    
                    if let leaveTime = trip.leaveTime {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Leave at")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatTime(leaveTime))
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    EmptyStateView(message: entry.error ?? "No trips", useSmallLayout: true)
                }
            }
            .padding(12)
        }
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
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.12), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 0) {
                if let trip = entry.nextTrip {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                            Text(trip.destinationName)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DEPARTURE")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                if let leaveTime = trip.leaveTime {
                                    Text(formatTime(leaveTime))
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ARRIVAL")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                Text(formatTime(trip.arrivalTime))
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let travelTime = trip.travelTimeMinutes {
                            Text("\(travelTime)m")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.blue)
                            Text("Travel Time")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        if let leaveTime = trip.leaveTime {
                            Text(timeUntilLeave(leaveTime))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.foregroundColor(.white))
                                .cornerRadius(6)
                                .padding(.top, 4)
                        }
                    }
                } else {
                    EmptyStateView(message: entry.error ?? "Plan your next move")
                }
            }
            .padding(16)
        }
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
    var useSmallLayout: Bool = false
    
    var body: some View {
        VStack(spacing: useSmallLayout ? 4 : 8) {
            Image(systemName: "map.fill")
                .font(useSmallLayout ? .title2 : .largeTitle)
                .foregroundColor(.blue.opacity(0.3))
            Text(message)
                .font(.system(size: useSmallLayout ? 12 : 14, weight: .bold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

