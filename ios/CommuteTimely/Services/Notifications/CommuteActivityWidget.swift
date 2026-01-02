//
// CommuteActivityWidget.swift
// CommuteTimely
//
// Live Activity widget views for Dynamic Island and Lock Screen
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftUI
import AppIntents

// Note: This widget should be in a separate Widget Extension target
// For now, we'll keep the activity manager logic separate
// The @main attribute should only be in the Widget Extension target
#if canImport(ActivityKit) && canImport(WidgetKit)
@available(iOS 16.1, *)
struct CommuteActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CommuteActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        if context.state.isNavigating {
            // Navigation mode - show distance and ETA like Google Maps
            HStack(spacing: 12) {
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(context.state.progressPercent) / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "car.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(context.state.distanceDisplayText)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(context.state.etaMinutes) min")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Text("to \(context.state.destinationName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Traffic indicator
                VStack(spacing: 2) {
                    Circle()
                        .fill(trafficColor(context.state.trafficSeverity))
                        .frame(width: 10, height: 10)
                    Text(context.state.trafficSeverity.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            // Normal mode - leave time countdown
            HStack(spacing: 12) {
                // Traffic indicator
                Circle()
                    .fill(trafficColor(context.state.trafficSeverity))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.state.firstName), leave in \(context.state.countdownMinutes) min")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(context.state.destinationName) • \(formatTime(context.state.leaveTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Weather icon
                Image(systemName: context.state.weatherCondition.icon)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func trafficColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .clear: return .green
        case .light: return .yellow
        case .moderate: return .orange
        case .heavy: return .red
        case .severe: return Color(red: 0.55, green: 0, blue: 0)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Dynamic Island Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        if context.state.isNavigating {
            // Navigation mode - show distance
            HStack(spacing: 4) {
                Image(systemName: "car.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text(context.state.distanceDisplayText)
                    .font(.system(size: 14, weight: .semibold))
            }
        } else {
            // Normal mode - countdown
            HStack(spacing: 4) {
                Circle()
                    .fill(trafficColor(context.state.trafficSeverity))
                    .frame(width: 6, height: 6)
                Text("\(context.state.countdownMinutes)m")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }
    
    private func trafficColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .clear: return .green
        case .light: return .yellow
        case .moderate: return .orange
        case .heavy: return .red
        case .severe: return Color(red: 0.55, green: 0, blue: 0)
        }
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        if context.state.isNavigating {
            // Navigation mode - show ETA
            HStack(spacing: 4) {
                Circle()
                    .fill(trafficColor(context.state.trafficSeverity))
                    .frame(width: 6, height: 6)
                Text("\(context.state.etaMinutes)m")
                    .font(.system(size: 12, weight: .medium))
            }
        } else {
            // Normal mode - weather and travel time
            HStack(spacing: 4) {
                Image(systemName: context.state.weatherCondition.icon)
                    .font(.system(size: 12))
                Text("\(context.state.travelTimeMinutes)m")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
    
    private func trafficColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .clear: return .green
        case .light: return .yellow
        case .moderate: return .orange
        case .heavy: return .red
        case .severe: return Color(red: 0.55, green: 0, blue: 0)
        }
    }
}

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(context.state.countdownMinutes)m")
                .font(.system(size: 14, weight: .semibold))
            if let emoji = context.state.destinationEmoji {
                Text(emoji)
                    .font(.system(size: 12))
            }
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good morning, \(context.state.firstName)")
                .font(.headline)
            Text("Leave in \(context.state.countdownMinutes) min")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(context.state.travelTimeMinutes) min")
                .font(.headline)
            Text("ETA")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<CommuteActivityAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // Traffic severity bar
            HStack {
                Text("Traffic")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(context.state.trafficSeverity.description)
                    .font(.caption.bold())
                    .foregroundColor(trafficColor(context.state.trafficSeverity))
            }
            
            // Weather forecast
            HStack {
                Image(systemName: context.state.weatherCondition.icon)
                Text("\(context.state.weatherCondition.description)")
                    .font(.caption)
                Spacer()
                Text("Updated \(formatLastUpdated(context.state.lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Destination and route info
            HStack {
                Text(context.state.destinationName)
                    .font(.subheadline.bold())
                Spacer()
                Button(intent: OpenMapIntent()) {
                    Label("Open Map", systemImage: "map")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func trafficColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .clear: return .green
        case .light: return .yellow
        case .moderate: return .orange
        case .heavy: return .red
        case .severe: return Color(red: 0.55, green: 0, blue: 0)
        }
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - App Intent for Button

@available(iOS 16.1, *)
struct OpenMapIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Map"
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Open the app to map view
        return .result()
    }
}
#endif

