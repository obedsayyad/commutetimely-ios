//
// TripPreviewView.swift
// CommuteTimely
//
// Preview trip with ML prediction
//

import SwiftUI

struct TripPreviewView: View {
    @ObservedObject var viewModel: TripPlannerViewModel
    @StateObject private var featureChecker = PremiumFeatureChecker.create()
    let onSave: () -> Void
    
    @State private var showingPaywall = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                if viewModel.state.isLoading {
                    ProgressView("Calculating best leave time...")
                        .padding(.top, DesignTokens.Spacing.xxl)
                } else if let prediction = viewModel.prediction {
                    predictionContent(prediction)
                } else if let error = viewModel.state.errorMessage {
                    errorContent(error)
                }
            }
            .padding()
        }
    }
    
    private func predictionContent(_ prediction: Prediction) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Leave time card
            CTCard {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Recommended Leave Time")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Text(formatTime(prediction.leaveTime))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                    
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Label(
                            "\(prediction.confidencePercentage)% confident",
                            systemImage: confidenceIcon(prediction.confidence)
                        )
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(confidenceColor(prediction.confidence))
                    }
                }
            }
            
            // Explanation
            CTCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Label("Why this time?", systemImage: "lightbulb.fill")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(prediction.explanation)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            
            // Route info
            if let route = viewModel.routeInfo {
                CTCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Label("Route Details", systemImage: "map.fill")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        HStack {
                            InfoPill(
                                icon: "arrow.left.arrow.right",
                                text: String(format: "%.1f mi", route.distanceInMiles)
                            )
                            
                            InfoPill(
                                icon: "clock.fill",
                                text: "\(Int(route.durationInMinutes)) min"
                            )
                            
                            InfoPill(
                                icon: "car.fill",
                                text: route.congestionLevel.description
                            )
                        }
                    }
                }
            }
            
            // Weather info
            if let weather = viewModel.weatherData {
                CTCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Label("Weather Conditions", systemImage: weather.conditions.icon)
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        HStack {
                            InfoPill(
                                icon: "thermometer",
                                text: "\(Int(weather.temperatureInFahrenheit))°F"
                            )
                            
                            InfoPill(
                                icon: "cloud.rain.fill",
                                text: "\(Int(weather.precipitationProbability))%"
                            )
                        }
                    }
                }
            }
            
            // Alternative leave times (Premium Feature)
            if !prediction.alternativeLeaveTimes.isEmpty {
                alternativeTimesSection(prediction.alternativeLeaveTimes)
                    .premiumFeatureGate("Alternative leave times with arrival probabilities")
            }
            
            // Save button
            CTButton("Save Trip", style: .primary) {
                onSave()
            }
            .padding(.top, DesignTokens.Spacing.md)
        }
    }
    
    private func errorContent(_ error: String) -> some View {
        CTInfoCard(
            title: "Unable to Calculate",
            message: error,
            icon: "exclamationmark.triangle.fill",
            style: .error
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func confidenceIcon(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "checkmark.circle.fill" }
        if confidence >= 0.6 { return "checkmark.circle" }
        return "questionmark.circle"
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .orange }
        return .red
    }
    
    private func alternativeTimesSection(_ alternatives: [AlternativeLeaveTime]) -> some View {
        CTCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    Label("Alternative Times", systemImage: "clock.arrow.2.circlepath")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Spacer()
                    
                    PremiumBadge()
                }
                
                Text("See other departure options with arrival probabilities")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                Divider()
                
                ForEach(alternatives) { alternative in
                    AlternativeTimeRow(alternative: alternative)
                }
            }
        }
    }
}

struct InfoPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(DesignTokens.Typography.caption)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.background)
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

struct AlternativeTimeRow: View {
    let alternative: AlternativeLeaveTime
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(alternative.leaveTime))
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(alternative.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(alternative.arrivalProbability * 100))%")
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(probabilityColor(alternative.arrivalProbability))
                
                Text("on time")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func probabilityColor(_ probability: Double) -> Color {
        if probability >= 0.9 { return .green }
        if probability >= 0.7 { return .orange }
        return .red
    }
}

#Preview {
    TripPreviewView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onSave: {}
    )
}

