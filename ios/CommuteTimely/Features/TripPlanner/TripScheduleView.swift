//
// TripScheduleView.swift
// CommuteTimely
//
// Set arrival time and schedule
//

import SwiftUI

struct TripScheduleView: View {
    @ObservedObject var viewModel: TripPlannerViewModel
    let onNext: () -> Void
    @State private var showingLocationPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // Origin Selection
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Starting From")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Where will you be leaving from?")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        // Current Location Option
                        OriginOptionButton(
                            icon: "location.fill",
                            title: "Current Location",
                            subtitle: "Use my location when it's time to leave",
                            isSelected: viewModel.selectedOrigin.isCurrentLocation
                        ) {
                            viewModel.selectedOrigin = .currentLocation
                        }
                        
                        // Custom Location Option
                        OriginOptionButton(
                            icon: "mappin.circle.fill",
                            title: viewModel.selectedOrigin.isCurrentLocation ? "Choose Location" : viewModel.selectedOrigin.displayName,
                            subtitle: "Set a specific starting point",
                            isSelected: !viewModel.selectedOrigin.isCurrentLocation
                        ) {
                            showingLocationPicker = true
                        }
                    }
                }
                
                // Arrival Time
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("When do you want to arrive?")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    DatePicker(
                        "Arrival Time",
                        selection: $viewModel.arrivalTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }
                
                // Buffer Minutes
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Buffer Time")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Extra time to account for unexpected delays")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Picker("Buffer", selection: $viewModel.bufferMinutes) {
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                        Text("30 min").tag(30)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Repeat Days
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Repeat")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Select days for recurring trips")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(WeekDay.allCases, id: \.self) { day in
                            DayButton(
                                day: day,
                                isSelected: viewModel.repeatDays.contains(day)
                            ) {
                                toggleDay(day)
                            }
                        }
                    }
                }
                
                // Preview Button
                CTButton("Preview Trip", style: .primary) {
                    Task {
                        await viewModel.fetchPrediction()
                        onNext()
                    }
                }
                .padding(.top, DesignTokens.Spacing.lg)
            }
            .padding()
        }
        .sheet(isPresented: $showingLocationPicker) {
            DestinationSearchView(
                viewModel: viewModel,
                isSelectingOrigin: true,
                onDismiss: {
                    showingLocationPicker = false
                }
            )
        }
    }
    
    private func toggleDay(_ day: WeekDay) {
        if viewModel.repeatDays.contains(day) {
            viewModel.repeatDays.remove(day)
        } else {
            viewModel.repeatDays.insert(day)
        }
    }
}

struct DayButton: View {
    let day: WeekDay
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(isSelected ? DesignTokens.Colors.primaryFallback() : DesignTokens.Colors.surface)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(DesignTokens.Colors.primaryFallback(), lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

// MARK: - Origin Option Button

struct OriginOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? DesignTokens.Colors.primaryFallback() : DesignTokens.Colors.textSecondary)
                    .frame(width: 40)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(isSelected ? DesignTokens.Colors.primaryFallback() : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TripScheduleView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onNext: {}
    )
}

