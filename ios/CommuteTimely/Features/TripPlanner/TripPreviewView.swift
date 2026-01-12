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
            
            // Alternative leave times (Standout Feature: Smart Forecast Graph)
            if !prediction.alternativeLeaveTimes.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack {
                        Label("Smart Forecast", systemImage: "chart.bar.fill")
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Spacer()
                        
                        if viewModel.weatherData?.precipitationProbability ?? 0 > 30 {
                            WeatherImpactBadge(minutes: 12) // In real app, calculate actual delay
                        }
                    }
                    
                    Text("Optimal leave window based on traffic & weather")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    ForecastGraphView(
                        alternatives: prediction.alternativeLeaveTimes,
                        recommendedLeaveTime: prediction.leaveTime
                    )
                    .frame(height: 120)
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .padding()
                .background(DesignTokens.Colors.surface)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .premiumFeatureGate("Smart Forecast Graph")
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
    
    private func probabilityColor(_ probability: Double) -> Color {
        if probability >= 0.9 { return .green }
        if probability >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - Standout Visuals

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

struct WeatherImpactBadge: View {
    let minutes: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cloud.rain.fill")
                .font(.system(size: 10))
            Text("+\(minutes)m delay")
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

struct ForecastGraphView: View {
    let alternatives: [AlternativeLeaveTime]
    let recommendedLeaveTime: Date
    
    private var allTimes: [Date] {
        var times = alternatives.map { $0.leaveTime }
        times.append(recommendedLeaveTime)
        return times.sorted()
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(allTimes, id: \.self) { time in
                let isRecommended = Calendar.current.isDate(time, equalTo: recommendedLeaveTime, toGranularity: .minute)
                let probability = probability(for: time)
                
                VStack(spacing: 8) {
                    // Probability Bar
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: isRecommended ? 16 : 12)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        probabilityColor(probability).opacity(isRecommended ? 1.0 : 0.6),
                                        probabilityColor(probability).opacity(isRecommended ? 0.8 : 0.4)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: isRecommended ? 16 : 12)
                            .frame(height: CGFloat(probability) * 80)
                    }
                    .frame(height: 80)
                    
                    // Time Label
                    Text(formatTime(time))
                        .font(.system(size: 10, weight: isRecommended ? .bold : .medium))
                        .foregroundColor(isRecommended ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func probability(for time: Date) -> Double {
        if Calendar.current.isDate(time, equalTo: recommendedLeaveTime, toGranularity: .minute) {
            return 0.95 // Recommended is always high confidence
        }
        return alternatives.first(where: { Calendar.current.isDate($0.leaveTime, equalTo: time, toGranularity: .minute) })?.arrivalProbability ?? 0.0
    }
    
    private func probabilityColor(_ probability: Double) -> Color {
        if probability >= 0.9 { return .green }
        if probability >= 0.7 { return .orange }
        return .red
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TripPreviewView(
        viewModel: DIContainer.shared.makeTripPlannerViewModel(),
        onSave: {}
    )
}

