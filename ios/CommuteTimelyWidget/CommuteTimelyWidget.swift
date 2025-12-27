//
// CommuteTimelyWidget.swift
// CommuteTimelyWidget
//
// Main widget configuration for Home Screen widgets
//

import WidgetKit
import SwiftUI

struct CommuteTimelyWidget: Widget {
    let kind: String = "CommuteTimelyWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripTimelineProvider()) { entry in
            CommuteTimelyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Commute Timely")
        .description("View your next trip and leave time at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

