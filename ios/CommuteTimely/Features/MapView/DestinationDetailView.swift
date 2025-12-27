//
//  DestinationDetailView.swift
//  CommuteTimely
//
//  Detail modal for reviewing and saving destinations.
//

import SwiftUI
import UIKit
import Combine
import CoreLocation

struct DestinationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DestinationDetailViewModel
    
    init(
        pin: MapDestinationPin,
        userCoordinate: Coordinate?,
        services: ServiceContainer = DIContainer.shared
    ) {
        _viewModel = StateObject(
            wrappedValue: DestinationDetailViewModel(
                destination: pin,
                userCoordinate: userCoordinate,
                mapboxService: services.mapboxService,
                weatherService: services.weatherService,
                predictionEngine: services.predictionEngine,
                tripStorageService: services.tripStorageService,
                subscriptionService: services.subscriptionService,
                leaveTimeScheduler: services.leaveTimeScheduler
            )
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                locationSection
                routeSection
                weatherSection
                predictionSection
                planningSection
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        CTInfoCard(
                            title: "Notice",
                            message: errorMessage,
                            icon: "info.circle.fill",
                            style: .info
                        )
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                }
                
                Section {
                    CTButton(
                        viewModel.isSaving ? "Saving..." : "Save Destination",
                        style: .primary,
                        isLoading: viewModel.isSaving,
                        isDisabled: viewModel.isSaving
                    ) {
                        viewModel.save()
                    }
                    .accessibilityLabel(viewModel.isSaving ? "Saving destination" : "Save destination")
                    .accessibilityHint("Saves this destination and schedules your leave-time notification")
                }
            }
            .navigationTitle(viewModel.titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                viewModel.load()
            }
            .onChange(of: viewModel.didSave) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView()
            }
            .onChange(of: viewModel.arrivalTime) { oldValue, newValue in
                // Recalculate prediction and weather when arrival time changes
                if oldValue != newValue {
                    Task {
                        await viewModel.fetchPrediction(force: true)
                        await viewModel.fetchWeather()
                    }
                }
            }
        }
    }
    
    private var locationSection: some View {
        Section("LOCATION") {
            Label(viewModel.locationSummaryTitle, systemImage: "mappin.circle.fill")
                .font(DesignTokens.Typography.subheadline.weight(.semibold))
            Text(viewModel.destination.location.address)
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(2)
            HStack {
                Text("Coordinates")
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Text(viewModel.coordinateText)
                    .font(.system(.footnote, design: .monospaced))
            }
        }
    }
    
    private var routeSection: some View {
        Section("ROUTE PREVIEW") {
            if let route = viewModel.routeInfo {
                InfoRow(title: "ETA", value: viewModel.etaDescription)
                InfoRow(title: "Distance", value: viewModel.distanceDescription)
                InfoRow(title: "Traffic", value: route.congestionLevel.description)
                    .foregroundColor(viewModel.trafficColor)
                
                if !route.alternativeRoutes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alternative routes")
                            .font(DesignTokens.Typography.caption.bold())
                        ForEach(route.alternativeRoutes.prefix(2)) { alternative in
                            Text("• \(alternative.routeName ?? "Option"): \(Int(alternative.durationInMinutes)) min")
                                .font(DesignTokens.Typography.caption)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            } else {
                Text("ETA will populate once we know your current location.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
    
    private var weatherSection: some View {
        Section("WEATHER AT ARRIVAL") {
            if let weather = viewModel.weatherData {
                HStack {
                    Image(systemName: weather.conditions.icon)
                        .foregroundColor(DesignTokens.Colors.info)
                    VStack(alignment: .leading) {
                        Text(weather.conditions.description)
                            .font(DesignTokens.Typography.subheadline)
                        Text(viewModel.weatherSummary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(weather.temperature))°")
                        .font(DesignTokens.Typography.title2)
                }
            } else {
                Text("I'm fetching the weather forecast for your arrival time.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
    
    private var predictionSection: some View {
        Section("LEAVE TIME PREDICTION") {
            if let recommendation = viewModel.predictionRecommendation {
                VStack(alignment: .leading, spacing: 12) {
                    // Recommended leave time
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommended Leave Time")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(formatLeaveTime(recommendation.recommendedLeaveTimeUtc))
                                .font(DesignTokens.Typography.title2)
                                .foregroundColor(DesignTokens.Colors.primaryFallback())
                        }
                        Spacer()
                        // Confidence indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(recommendation.prediction.confidence * 100))% confidence")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            confidenceBadge(confidence: recommendation.prediction.confidence)
                        }
                    }
                    
                    Divider()
                    
                    // Travel time breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Travel Time")
                                .font(DesignTokens.Typography.subheadline)
                            Spacer()
                            Text("\(Int(recommendation.snapshot.route.totalDurationWithTraffic / 60)) min")
                                .font(DesignTokens.Typography.subheadline.bold())
                        }
                        
                        if recommendation.weatherPenaltyMinutes > 0 {
                            HStack {
                                Image(systemName: "cloud.rain.fill")
                                    .foregroundColor(DesignTokens.Colors.info)
                                    .font(.caption)
                                Text("Weather Impact")
                                    .font(DesignTokens.Typography.subheadline)
                                Spacer()
                                Text("+\(recommendation.weatherPenaltyMinutes) min")
                                    .font(DesignTokens.Typography.subheadline)
                                    .foregroundColor(DesignTokens.Colors.warning)
                            }
                        }
                        
                        if recommendation.userBufferMinutes > 0 {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .font(.caption)
                                Text("Buffer")
                                    .font(DesignTokens.Typography.subheadline)
                                Spacer()
                                Text("+\(recommendation.userBufferMinutes) min")
                                    .font(DesignTokens.Typography.subheadline)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Explanation
                    Text(recommendation.explanation)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Last updated
                    if let lastUpdated = viewModel.lastUpdated {
                        HStack {
                            Spacer()
                            Text("Last updated \(formatLastUpdated(lastUpdated))")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Recalculate button
                Button {
                    viewModel.recalculatePrediction()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if viewModel.isRecalculating {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(viewModel.isRecalculating ? "Recalculating..." : "Recalculate Now")
                            .font(DesignTokens.Typography.callout)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignTokens.Size.buttonHeightCompact)
                }
                .disabled(viewModel.isRecalculating)
                .accessibilityLabel("Recalculate leave time")
                .accessibilityHint("Updates the prediction with the latest traffic and weather data")
            } else {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Calculating when you should leave...")
                        .font(DesignTokens.Typography.footnote)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .accessibilityLabel("Calculating leave time")
            }
        }
    }
    
    private func formatLeaveTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func confidenceBadge(confidence: Double) -> some View {
        let color: Color
        let text: String
        
        if confidence >= 0.8 {
            color = DesignTokens.Colors.success
            text = "High"
        } else if confidence >= 0.6 {
            color = DesignTokens.Colors.warning
            text = "Medium"
        } else {
            color = DesignTokens.Colors.error
            text = "Low"
        }
        
        return Text(text)
            .font(DesignTokens.Typography.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    
    private var planningSection: some View {
        Section("PLAN DETAILS") {
            TextField("Custom name", text: $viewModel.customName)
                .textInputAutocapitalization(.words)
            TextEditor(text: $viewModel.notes)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.Colors.divider, lineWidth: 1)
                )
                .accessibilityLabel("Notes")
            
            DatePicker("Arrive by", selection: $viewModel.arrivalTime, displayedComponents: [.date, .hourAndMinute])
            
            Stepper(value: $viewModel.bufferMinutes, in: 0...60, step: 5) {
                Text("Buffer: \(viewModel.bufferMinutes) min")
            }
            
            Picker("Transport", selection: $viewModel.transportMode) {
                ForEach(TransportMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                WrapHStack(viewModel.availableTags) { tag in
                    TagChip(title: tag.displayName, isSelected: viewModel.tags.contains(tag)) {
                        viewModel.toggle(tag: tag)
                    }
                }
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Spacer()
            Text(value)
        }
    }
}

private struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? DesignTokens.Colors.primaryFallback().opacity(0.15) : DesignTokens.Colors.surface)
                .foregroundColor(isSelected ? DesignTokens.Colors.primaryFallback() : DesignTokens.Colors.textPrimary)
                .cornerRadius(DesignTokens.CornerRadius.round)
        }
        .buttonStyle(.plain)
    }
}

private struct WrapHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        FlexibleView(
            availableWidth: UIScreen.main.bounds.width - 64,
            data: data,
            spacing: 8,
            alignment: .leading,
            content: content
        )
    }
}

private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let availableWidth: CGFloat
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    @State private var elementsSize: [Data.Element: CGSize] = [:]
    
    private var rows: [[Data.Element]] {
        var width: CGFloat = 0
        var result: [[Data.Element]] = [[]]
        
        for element in data {
            let elementSize = elementsSize[element, default: CGSize(width: availableWidth, height: 1)]
            if width + elementSize.width > availableWidth {
                width = elementSize.width
                result.append([element])
            } else {
                result[result.count - 1].append(element)
                width += elementSize.width
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { element in
                        content(element)
                            .fixedSize()
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            elementsSize[element] = geo.size
                                        }
                                }
                            )
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DestinationDetailViewModel: ObservableObject {
    @Published var customName: String
    @Published var notes: String
    @Published var transportMode: TransportMode = .driving
    @Published var arrivalTime: Date = Date().addingTimeInterval(3600)
    @Published var bufferMinutes: Int = 10
    @Published var tags: Set<DestinationTag> = []
    @Published var routeInfo: RouteInfo?
    @Published var weatherData: WeatherData?
    @Published var predictionRecommendation: LeaveTimeRecommendation?
    @Published var isSaving = false
    @Published var isRecalculating = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var lastUpdated: Date?
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var showPaywall = false
    
    let destination: MapDestinationPin
    private let userCoordinate: Coordinate?
    private let mapboxService: MapboxServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let predictionEngine: PredictionEngineProtocol
    private let tripStorageService: TripStorageServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let leaveTimeScheduler: LeaveTimeSchedulerProtocol
    private var hasLoaded = false
    private var routeSnapshot: RouteSnapshot?
    private let existingTripID: UUID?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        destination: MapDestinationPin,
        userCoordinate: Coordinate?,
        mapboxService: MapboxServiceProtocol,
        weatherService: WeatherServiceProtocol,
        predictionEngine: PredictionEngineProtocol,
        tripStorageService: TripStorageServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        leaveTimeScheduler: LeaveTimeSchedulerProtocol
    ) {
        self.destination = destination
        self.userCoordinate = userCoordinate
        self.mapboxService = mapboxService
        self.weatherService = weatherService
        self.predictionEngine = predictionEngine
        self.tripStorageService = tripStorageService
        self.subscriptionService = subscriptionService
        self.leaveTimeScheduler = leaveTimeScheduler
        self.customName = destination.customName ?? destination.title
        self.notes = ""
        self.tags = destination.tags
        self.existingTripID = destination.tripID
        
        // Subscribe to subscription status updates
        subscriptionService.subscriptionStatus
            .sink { [weak self] status in
                self?.subscriptionStatus = status
            }
            .store(in: &cancellables)
    }
    
    var titleText: String {
        destination.title
    }
    
    var locationSummaryTitle: String {
        destination.customName ?? destination.title
    }
    
    var coordinateText: String {
        let coord = destination.coordinate
        return String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
    }
    
    var etaDescription: String {
        guard let routeInfo else { return "—" }
        let minutes = Int(routeInfo.totalDurationWithTraffic / 60)
        return "\(minutes) min"
    }
    
    var distanceDescription: String {
        guard let routeInfo else { return "—" }
        return String(format: "%.1f mi", routeInfo.distanceInMiles)
    }
    
    var weatherSummary: String {
        guard let weatherData else { return "Forecast pending" }
        return "\(Int(weatherData.temperature))° • \(Int(weatherData.precipitationProbability))% precip"
    }
    
    var availableTags: [DestinationTag] {
        DestinationTag.allCases
    }
    
    var trafficColor: Color {
        guard let level = routeInfo?.congestionLevel else {
            return DesignTokens.Colors.textSecondary
        }
        
        switch level {
        case .none, .low:
            return DesignTokens.Colors.trafficClear
        case .moderate:
            return DesignTokens.Colors.trafficModerate
        case .heavy, .severe:
            return DesignTokens.Colors.trafficSevere
        }
    }
    
    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task {
            await fetchRoute()
        }
        Task {
            await fetchWeather()
        }
        Task {
            await hydrateFromExistingTrip()
        }
        Task {
            await fetchPrediction()
        }
    }
    
    func recalculatePrediction() {
        Task {
            await fetchPrediction(force: true)
        }
    }
    
    func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        
        Task {
            // If updating existing trip, no need to check subscription limit
            if let tripID = existingTripID,
               var existing = await tripStorageService.fetchTrip(id: tripID) {
                do {
                    update(&existing)
                    try await tripStorageService.updateTrip(existing)
                    await leaveTimeScheduler.rescheduleTrip(existing, reason: "Destination updated")
                    await MainActor.run {
                        self.isSaving = false
                        self.didSave = true
                    }
                } catch {
                    await MainActor.run {
                        self.isSaving = false
                        self.errorMessage = error.localizedDescription
                    }
                }
                return
            }
            
            // For new trips, check subscription limit
            await refreshSubscriptionStatus()
            let canCreate = await tripStorageService.canCreateTrip(
                isSubscribed: subscriptionStatus.isSubscribed,
                subscriptionTier: subscriptionStatus.subscriptionTier
            )
            
            if !canCreate {
                // Show paywall for free users who have reached daily limit
                await MainActor.run {
                    self.isSaving = false
                    self.showPaywall = true
                }
                return
            }
            
            do {
                let trip = Trip(
                    destination: destination.location,
                    arrivalTime: arrivalTime,
                    bufferMinutes: max(bufferMinutes, 0),
                    customName: trimmed(customName),
                    notes: trimmed(notes),
                    transportMode: transportMode,
                    tags: tags,
                    lastRouteSnapshot: routeSnapshot,
                    expectedWeatherSummary: weatherSummary,
                    arrivalBufferMinutes: bufferMinutes
                )
                try await tripStorageService.saveTrip(trip)
                await leaveTimeScheduler.scheduleTrip(trip)
                await MainActor.run {
                    self.isSaving = false
                    self.didSave = true
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func refreshSubscriptionStatus() async {
        await subscriptionService.refreshSubscriptionStatus()
    }
    
    func toggle(tag: DestinationTag) {
        if tags.contains(tag) {
            tags.remove(tag)
        } else {
            tags.insert(tag)
        }
    }
    
    private func fetchRoute() async {
        guard let origin = userCoordinate else { return }
        do {
            let route = try await mapboxService.getRoute(from: origin, to: destination.location.coordinate)
            await MainActor.run {
                self.routeInfo = route
                self.routeSnapshot = RouteSnapshot(
                    travelTimeMinutes: Int(route.totalDurationWithTraffic / 60),
                    trafficSummary: route.congestionLevel.description,
                    congestionLevel: route.congestionLevel,
                    capturedAt: Date(),
                    distanceMeters: route.distance
                )
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "I couldn't fetch traffic data right now. Trying again in a moment."
            }
        }
    }
    
    func fetchWeather() async {
        do {
            // Get hourly forecast and find weather for arrival time
            let hourlyForecast = try await weatherService.getHourlyForecast(at: destination.location.coordinate)
            
            // Find the hour closest to arrival time
            let arrivalTime = self.arrivalTime
            let closestHour = hourlyForecast.min(by: { hour1, hour2 in
                abs(hour1.timestamp.timeIntervalSince(arrivalTime)) < abs(hour2.timestamp.timeIntervalSince(arrivalTime))
            })
            
            // Convert HourlyWeather to WeatherData
            if let hour = closestHour {
                // Use the hourly forecast data, with some defaults for missing fields
                let weather = WeatherData(
                    temperature: hour.temperature,
                    feelsLike: hour.temperature, // Approximate feels like from temperature
                    conditions: hour.conditions,
                    precipitation: 0.0, // Hourly forecast doesn't include precipitation amount
                    precipitationProbability: hour.precipitationProbability,
                    windSpeed: hour.windSpeed,
                    windDirection: 0, // Not available in hourly forecast
                    visibility: 10.0, // Default visibility
                    humidity: 60, // Default humidity
                    pressure: 1013.25, // Default pressure
                    uvIndex: 0, // Not available in hourly forecast
                    cloudCoverage: hour.conditions == .clear ? 0 : 50, // Estimate from conditions
                    timestamp: hour.timestamp,
                    alerts: []
                )
                
                await MainActor.run {
                    self.weatherData = weather
                    // Clear any previous weather error message
                    if self.errorMessage == "Weather forecast temporarily unavailable. Your route is still calculated." {
                        self.errorMessage = nil
                    }
                }
            } else {
                // Fallback to current weather if no forecast available
                let weather = try await weatherService.getCurrentWeather(at: destination.location.coordinate)
                await MainActor.run {
                    self.weatherData = weather
                    if self.errorMessage == "Weather forecast temporarily unavailable. Your route is still calculated." {
                        self.errorMessage = nil
                    }
                }
            }
        } catch {
            // Try to get current weather as fallback
            do {
                let currentWeather = try await weatherService.getCurrentWeather(at: destination.location.coordinate)
                await MainActor.run {
                    self.weatherData = currentWeather
                    // Clear error message if we got current weather successfully
                    if self.errorMessage == "Weather forecast temporarily unavailable. Your route is still calculated." {
                        self.errorMessage = nil
                    }
                }
            } catch {
                // Only show error if we couldn't get either forecast or current weather
                await MainActor.run {
                    // Only set error if we don't have any weather data
                    if self.weatherData == nil {
                        self.errorMessage = "Weather forecast temporarily unavailable. Your route is still calculated."
                    }
                }
            }
        }
    }
    
    private func hydrateFromExistingTrip() async {
        guard let tripID = existingTripID,
              let trip = await tripStorageService.fetchTrip(id: tripID) else { return }
        await MainActor.run {
            self.customName = trip.customName ?? destination.title
            self.notes = trip.notes ?? ""
            self.transportMode = trip.transportMode
            self.arrivalTime = trip.arrivalTime
            self.bufferMinutes = trip.bufferMinutes
            self.tags = trip.tags
        }
    }
    
    func fetchPrediction(force: Bool = false) async {
        guard let origin = userCoordinate else { return }
        
        await MainActor.run {
            if force {
                isRecalculating = true
            }
        }
        
        let recommendation = await predictionEngine.recommendation(
            origin: origin,
            destination: destination.location.coordinate,
            arrivalTime: arrivalTime
        )
        
        await MainActor.run {
            self.predictionRecommendation = recommendation
            self.lastUpdated = Date()
            self.isRecalculating = false
        }
    }
    
    private func update(_ trip: inout Trip) {
        trip.customName = trimmed(customName)
        trip.notes = trimmed(notes)
        trip.transportMode = transportMode
        trip.arrivalTime = arrivalTime
        trip.bufferMinutes = bufferMinutes
        trip.arrivalBufferMinutes = bufferMinutes
        trip.tags = tags
        trip.lastRouteSnapshot = routeSnapshot
        trip.expectedWeatherSummary = weatherSummary
    }
    
    private func trimmed(_ string: String) -> String? {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension TransportMode {
    var displayName: String {
        switch self {
        case .driving: return "Drive"
        case .walking: return "Walk"
        case .transit: return "Transit"
        case .cycling: return "Bike"
        }
    }
}

private extension DestinationTag {
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .favorite: return "Favorite"
        case .urgent: return "Important"
        }
    }
}

