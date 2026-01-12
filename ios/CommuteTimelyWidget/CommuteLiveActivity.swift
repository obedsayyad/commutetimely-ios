//
// CommuteLiveActivity.swift
// CommuteTimelyWidgetExtension
//
// Live Activity widget views for Dynamic Island and Lock Screen
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 16.1, *)
struct CommuteActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var firstName: String
        var leaveTime: Date
        var travelTimeMinutes: Int
        var trafficSeverity: TrafficSeverity
        var weatherCondition: WeatherCondition
        var destinationName: String
        var destinationEmoji: String?
        var lastUpdated: Date
        var countdownMinutes: Int
        var eta: Date
        
        // Navigation mode properties
        var isNavigating: Bool = false
        var distanceRemainingKm: Double = 0
        var progressPercent: Int = 0
        var currentSpeedKmh: Int = 0
        var etaMinutes: Int = 0
        
        var trafficColor: String {
            switch trafficSeverity {
            case .clear: return "green"
            case .light: return "yellow"
            case .moderate: return "orange"
            case .heavy: return "red"
            case .severe: return "darkRed"
            }
        }
        
        var distanceDisplayText: String {
            if distanceRemainingKm < 1 {
                return "\(Int(distanceRemainingKm * 1000)) m"
            } else {
                return String(format: "%.1f km", distanceRemainingKm)
            }
        }
    }
    
    // Fixed non-changing properties about your activity go here!
    var tripId: String
    var destinationAddress: String
    var destinationLatitude: Double = 0
    var destinationLongitude: Double = 0
}

enum TrafficSeverity: String, Codable {
    case clear
    case light
    case moderate
    case heavy
    case severe
    
    var description: String {
        switch self {
        case .clear: return "Clear"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .severe: return "Severe"
        }
    }
}

// Need to duplicate WeatherCondition if it's not available
// Assuming WeatherCondition is a simple string or enum that needs dragging in too?
// Checking the original file... WeatherCondition was NOT in CommuteActivityAttributes definition I saw earlier?
// Wait, looking at Step 1046: var weatherCondition: WeatherCondition
// Where is WeatherCondition defined? It wasn't in CommuteActivity.swift!
// It must be imported or defined elsewhere. 
// If it's in a helper file, I need that too.
// Let's check WeatherCondition definition.

}

enum WeatherCondition: String, Codable {
    case clear
    case partlyCloudy
    case cloudy
    case overcast
    case mist
    case fog
    case lightRain
    case rain
    case heavyRain
    case drizzle
    case lightSnow
    case snow
    case heavySnow
    case sleet
    case freezingRain
    case thunderstorm
    case hail
    case unknown
    
    var icon: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .overcast: return "cloud.fill"
        case .mist, .fog: return "cloud.fog.fill"
        case .lightRain, .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .lightSnow: return "cloud.snow.fill"
        case .snow, .heavySnow: return "cloud.snow.fill"
        case .sleet: return "cloud.sleet.fill"
        case .freezingRain: return "cloud.hail.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .hail: return "cloud.hail.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .overcast: return "Overcast"
        case .mist: return "Misty"
        case .fog: return "Foggy"
        case .lightRain: return "Light Rain"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .drizzle: return "Drizzle"
        case .lightSnow: return "Light Snow"
        case .snow: return "Snow"
        case .heavySnow: return "Heavy Snow"
        case .sleet: return "Sleet"
        case .freezingRain: return "Freezing Rain"
        case .thunderstorm: return "Thunderstorm"
        case .hail: return "Hail"
        case .unknown: return "Unknown"
        }
    }
}

@available(iOS 16.1, *)
struct CommuteLiveActivity: Widget {
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
        VStack(spacing: 0) {
            if context.state.isNavigating {
                // MARK: - Navigation Mode (Google Maps Style)
                VStack(alignment: .leading, spacing: 4) {
                    // Header: Title and Icon
                    HStack(alignment: .firstTextBaseline) {
                        Text("Drive \(context.state.etaMinutes) min (\(context.state.distanceDisplayText))")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "map.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    
                    // Subtitle: Arrival Time & Destination
                    Text("Arrive \(formatTime(context.state.eta)) • \(context.state.destinationName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Progress Bar Area
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(45)) // Navigation arrow orientation
                        
                        // Linear Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 6)
                                
                                // Active Progress
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * Double(context.state.progressPercent) / 100)), height: 6)
                                
                                // Car/Puck Indicator
                                Image(systemName: "circle.circle.fill") // Using a distinct puck icon
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                                    .background(Circle().fill(Color.blue).frame(width: 10, height: 10)) // small background to hide line behind
                                    .offset(x: max(0, min(geometry.size.width - 14, geometry.size.width * Double(context.state.progressPercent) / 100 - 7)))
                            }
                        }
                        .frame(height: 14)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.top, 12)
                    
                    // Footer: Traffic Warning (if needed)
                    if context.state.trafficSeverity == .heavy || context.state.trafficSeverity == .severe {
                         Text("Heavy traffic on route")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
                .activityBackgroundTint(Color(red: 0.1, green: 0.1, blue: 0.1)) // Dark background like the screenshot
                .activitySystemActionForegroundColor(.white)
                
            } else {
                // MARK: - Pre-Trip Mode (Countdown)
                HStack(alignment: .center, spacing: 16) {
                    // Left: Time & Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leave in \(context.state.countdownMinutes) min")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.8)
                        
                        Text("for \(context.state.destinationName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Label(context.state.weatherCondition.description, systemImage: context.state.weatherCondition.icon)
                                .font(.caption2)
                            Text("•")
                            Text("Traffic: \(context.state.trafficSeverity.description)")
                                .font(.caption2)
                                .foregroundColor(trafficColor(context.state.trafficSeverity))
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Right: Circular Progress for "Time to Leave"
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: 0.75) // Placeholder trim, would be dynamic in real app
                            .stroke(trafficColor(context.state.trafficSeverity), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "car.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .frame(width: 50, height: 50)
                }
                .padding(20)
                .activityBackgroundTint(Color(red: 0.1, green: 0.1, blue: 0.1))
                .activitySystemActionForegroundColor(.white)
            }
        }
    }
    
    private func trafficColor(_ severity: TrafficSeverity) -> Color {
        switch severity {
        case .clear: return .green
        case .light: return .yellow
        case .moderate: return .orange
        case .heavy: return .red
        case .severe: return Color(red: 0.8, green: 0, blue: 0)
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
