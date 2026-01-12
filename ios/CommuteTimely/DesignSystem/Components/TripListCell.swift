//
// TripListCell.swift
// CommuteTimely
//
// Trip list cell component showing trip details
//

import SwiftUI

struct TripListCell: View {
    let trip: Trip
    let onToggle: ((Bool) -> Void)?
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(
        trip: Trip,
        onToggle: ((Bool) -> Void)? = nil,
        onTap: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.trip = trip
        self.onToggle = onToggle
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Location Icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primaryFallback().opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: DesignTokens.Size.iconMedium))
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
                
                // Trip Details
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(trip.destination.displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(
                            formattedArrivalTime,
                            systemImage: "clock.fill"
                        )
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        if !trip.repeatDays.isEmpty {
                            Text("•")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            
                            Text(repeatDaysText)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    
                    if trip.bufferMinutes > 0 {
                        Text("Buffer: \(trip.bufferMinutes) min")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Delete Button
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Active Toggle
                if let onToggle = onToggle {
                    Toggle("", isOn: Binding(
                        get: { trip.isActive },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: DesignTokens.Colors.primaryFallback()))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .padding(DesignTokens.Spacing.md)
            .glassStyle()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip to \(trip.destination.displayName), arrive by \(formattedArrivalTime)")
        .accessibilityHint("Double tap to edit trip")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button {
                onTap?()
            } label: {
                Label("Edit Trip", systemImage: "pencil")
            }
            
            Button {
                if let onToggle = onToggle {
                    onToggle(!trip.isActive)
                }
            } label: {
                if trip.isActive {
                    Label("Deactivate", systemImage: "bell.slash")
                } else {
                    Label("Activate", systemImage: "bell")
                }
            }
            
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: trip.arrivalTime)
    }
    
    private var repeatDaysText: String {
        if trip.repeatDays.count == 7 {
            return "Every day"
        } else if trip.repeatDays.count == 5 &&
                  trip.repeatDays.contains(.monday) &&
                  trip.repeatDays.contains(.tuesday) &&
                  trip.repeatDays.contains(.wednesday) &&
                  trip.repeatDays.contains(.thursday) &&
                  trip.repeatDays.contains(.friday) {
            return "Weekdays"
        } else if trip.repeatDays.count <= 3 {
            return trip.repeatDays.sorted(by: { $0.rawValue < $1.rawValue })
                .map { $0.shortName }
                .joined(separator: ", ")
        } else {
            return "\(trip.repeatDays.count) days"
        }
    }
}

#Preview("Trip Cell") {
    VStack(spacing: 16) {
        TripListCell(
            trip: Trip(
                destination: Location(
                    coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                    address: "123 Market St, San Francisco, CA",
                    placeName: "Office",
                    placeType: .work
                ),
                arrivalTime: Date().addingTimeInterval(3600),
                bufferMinutes: 15,
                repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday]
            ),
            onToggle: { _ in }
        )
        
        TripListCell(
            trip: Trip(
                destination: Location(
                    coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                    address: "456 Gym Ave, San Francisco, CA",
                    placeName: "Gym",
                    placeType: .gym
                ),
                arrivalTime: Date().addingTimeInterval(7200),
                bufferMinutes: 10
            ),
            onTap: {}
        )
    }
    .padding()
    .background(DesignTokens.Colors.background)
}

