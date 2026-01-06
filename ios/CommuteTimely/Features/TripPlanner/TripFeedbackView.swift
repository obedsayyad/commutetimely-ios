//
// TripFeedbackView.swift
// CommuteTimely
//
// Post-trip feedback collection for ML improvement
//

import SwiftUI

struct TripFeedbackView: View {
    let trip: Trip
    let actualArrivalTime: Date
    let onSubmit: (TripFeedback) -> Void
    let onDismiss: () -> Void
    
    @State private var arrivalStatus: ArrivalStatus = .onTime
    @State private var minutesDifference: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()
                
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                .padding(.bottom, DesignTokens.Spacing.md)
                
                // Header
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Trip Complete!")
                        .font(DesignTokens.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Help us improve your predictions")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                // Arrival Status
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Did you arrive on time?")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Picker("Arrival Status", selection: $arrivalStatus) {
                        Text("On Time ✅").tag(ArrivalStatus.onTime)
                        Text("Early 🎉").tag(ArrivalStatus.early)
                        Text("Late ⏰").tag(ArrivalStatus.late)
                    }
                    .pickerStyle(.segmented)
                    
                    if arrivalStatus != .onTime {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("By how many minutes?")
                                .font(DesignTokens.Typography.callout)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            
                            HStack {
                                Button {
                                    if minutesDifference > 1 {
                                        minutesDifference -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                                }
                                
                                Spacer()
                                
                                Text("\\(minutesDifference)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text("min")
                                    .font(DesignTokens.Typography.title3)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                
                                Spacer()
                                
                                Button {
                                    if minutesDifference < 60 {
                                        minutesDifference += 1
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                                }
                            }
                            .padding(.vertical, DesignTokens.Spacing.md)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.surface)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                
                Spacer()
                
                // Buttons
                VStack(spacing: DesignTokens.Spacing.md) {
                    CTButton("Submit Feedback", style: .primary) {
                        let feedback = TripFeedback(
                            tripId: trip.id,
                            arrivalStatus: arrivalStatus,
                            minutesDifference: arrivalStatus == .onTime ? 0 : minutesDifference,
                            actualArrivalTime: actualArrivalTime
                        )
                        onSubmit(feedback)
                    }
                    
                    Button("Skip") {
                        onDismiss()
                    }
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            // Set initial value if not on time
            if arrivalStatus != .onTime {
                minutesDifference = 5
            }
        }
    }
}

// MARK: - Models

enum ArrivalStatus: String, Codable {
    case onTime
    case early
    case late
    
    var displayName: String {
        switch self {
        case .onTime: return "On Time"
        case .early: return "Early"
        case .late: return "Late"
        }
    }
}

struct TripFeedback: Codable {
    let tripId: UUID
    let arrivalStatus: ArrivalStatus
    let minutesDifference: Int
    let actualArrivalTime: Date
    let submittedAt: Date = Date()
    
    var accuracyScore: Double {
        switch arrivalStatus {
        case .onTime:
            return 1.0
        case .early, .late:
            // Decrease score based on minutes difference
            // 5 min = 0.8, 10 min = 0.6, 15 min = 0.4, 20+ min = 0.2
            let score = max(0.2, 1.0 - (Double(minutesDifference) / 25.0))
            return score
        }
    }
}

#Preview {
    TripFeedbackView(
        trip: Trip(
            destination: Location(
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
                address: "123 Main St, San Francisco, CA"
            ),
            arrivalTime: Date()
        ),
        actualArrivalTime: Date(),
        onSubmit: { _ in },
        onDismiss: {}
    )
}
