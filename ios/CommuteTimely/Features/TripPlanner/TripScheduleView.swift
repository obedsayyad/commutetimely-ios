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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
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
                
                Spacer()
                
                CTButton("Preview Trip", style: .primary) {
                    Task {
                        await viewModel.fetchPrediction()
                        onNext()
                    }
                }
            }
            .padding()
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

#Preview {
    TripScheduleView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onNext: {}
    )
}

