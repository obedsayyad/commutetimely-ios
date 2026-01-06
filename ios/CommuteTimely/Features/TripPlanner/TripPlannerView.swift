//
// TripPlannerView.swift
// CommuteTimely
//
// Main trip creation/editing view with wizard flow
//

import SwiftUI
import Combine

struct TripPlannerView: View {
    let mode: TripPlannerMode
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TripPlannerViewModel
    
    @State private var currentStep: PlannerStep = .destination
    
    init(mode: TripPlannerMode) {
        self.mode = mode
        self._viewModel = StateObject(wrappedValue: DIContainer.shared.makeTripPlannerViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress
                    progressBar
                    
                    // Current step view
                    Group {
                        switch currentStep {
                        case .destination:
                            DestinationSearchView(
                                viewModel: viewModel,
                                onNext: { currentStep = .schedule }
                            )
                        case .schedule:
                            TripScheduleView(
                                viewModel: viewModel,
                                onNext: { currentStep = .preview }
                            )
                        case .preview:
                            TripPreviewView(
                                viewModel: viewModel,
                                onSave: {
                                    Task {
                                        await viewModel.saveTrip()
                                        // Check if paywall was shown - if not, dismiss
                                        await MainActor.run {
                                            if !viewModel.showPaywall {
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .navigationTitle(mode == .create ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .animation(DesignTokens.Animation.adaptive(DesignTokens.Animation.springSmooth), value: currentStep)
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView()
            }
        }
    }
    
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(PlannerStep.allCases, id: \.self) { step in
                Rectangle()
                    .fill(step.rawValue <= currentStep.rawValue ?
                          DesignTokens.Colors.primaryFallback() :
                            Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

enum PlannerStep: Int, CaseIterable {
    case destination = 0
    case schedule = 1
    case preview = 2
}

// MARK: - Trip Planner ViewModel

@MainActor
class TripPlannerViewModel: BaseViewModel {
    @Published var selectedOrigin: TripOrigin = .currentLocation
    @Published var selectedDestination: Location?
    @Published var arrivalTime = Date().addingTimeInterval(3600) // 1 hour from now
    @Published var bufferMinutes = 10
    @Published var repeatDays: Set<WeekDay> = []
    
    @Published var routeInfo: RouteInfo?
    @Published var weatherData: WeatherData?
    @Published var prediction: Prediction?
    
    @Published var isSaving = false
    private var lastSaveTime: Date = .distantPast
    
    private let mapboxService: MapboxServiceProtocol
    private let searchService: SearchServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let mlPredictionService: MLPredictionServiceProtocol
    private let tripStorageService: TripStorageServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let leaveTimeScheduler: LeaveTimeSchedulerProtocol
    private let locationService: LocationServiceProtocol
    
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var showPaywall = false
    
    init(
        mapboxService: MapboxServiceProtocol,
        searchService: SearchServiceProtocol,
        weatherService: WeatherServiceProtocol,
        mlPredictionService: MLPredictionServiceProtocol,
        tripStorageService: TripStorageServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        leaveTimeScheduler: LeaveTimeSchedulerProtocol,
        locationService: LocationServiceProtocol
    ) {
        self.mapboxService = mapboxService
        self.searchService = searchService
        self.weatherService = weatherService
        self.mlPredictionService = mlPredictionService
        self.tripStorageService = tripStorageService
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
        self.leaveTimeScheduler = leaveTimeScheduler
        self.locationService = locationService
        super.init()
        
        // Subscribe to subscription status updates
        subscriptionService.subscriptionStatus
            .sink { [weak self] status in
                self?.subscriptionStatus = status
            }
            .store(in: &cancellables)
    }
    
    func searchDestinations(query: String, userCoordinate: Coordinate? = nil) async throws -> [Location] {
        // Use SearchService which has all the improvements (smart region detection, query preprocessing, relevance scoring, fuzzy matching)
        let response = try await searchService.suggestions(for: query, userCoordinate: userCoordinate)
        
        // Extract Location from SearchSuggestion
        let locations = response.suggestions.map { $0.location }
        
        return locations
    }
    
    func fetchPrediction() async {
        guard let destination = selectedDestination else { return }
        
        setLoading()
        
        // Get actual origin based on user selection
        let origin: Coordinate
        switch selectedOrigin {
        case .currentLocation:
            // Use location service to get current location
            do {
                let location = try await locationService.getCurrentLocation()
                origin = Coordinate(clCoordinate: location.coordinate)
            } catch {
                print("[TripPlanner] Location fetch failed: \(error.localizedDescription)")
                setError("Unable to get current location. Please check location permissions.")
                return
            }
        case .customLocation(let location):
            origin = location.coordinate
        }
        
        // Try to fetch route, fallback to estimated route if it fails
        var route: RouteInfo
        do {
            route = try await mapboxService.getRoute(from: origin, to: destination.coordinate)
            self.routeInfo = route
        } catch {
            // Create fallback route based on distance
            print("[TripPlanner] Route fetch failed: \(error.localizedDescription). Using estimated route.")
            route = createFallbackRoute(from: origin, to: destination.coordinate)
            self.routeInfo = route
        }
        
        // Try to fetch weather, fallback to default weather if it fails
        var weather: WeatherData
        do {
            weather = try await weatherService.getCurrentWeather(at: destination.coordinate)
            self.weatherData = weather
        } catch {
            // Create fallback weather data
            print("[TripPlanner] Weather fetch failed: \(error.localizedDescription). Using default weather.")
            weather = createFallbackWeather()
            self.weatherData = weather
        }
        
        // Get ML prediction (this will use CoreML fallback if server fails)
        do {
            let pred = try await mlPredictionService.predict(
                origin: origin,
                destination: destination.coordinate,
                arrivalTime: arrivalTime,
                routeInfo: route,
                weather: weather
            )
            self.prediction = pred
            setLoaded()
        } catch {
            // Only show error if prediction completely fails (shouldn't happen with CoreML fallback)
            print("[TripPlanner] Prediction failed: \(error.localizedDescription)")
            setError("Unable to calculate leave time. Please try again.")
        }
    }
    
    // MARK: - Fallback Helpers
    
    private func createFallbackRoute(from origin: Coordinate, to destination: Coordinate) -> RouteInfo {
        // Calculate distance using Haversine formula
        let distance = origin.distance(to: destination)
        
        // Estimate duration based on distance (assuming average speed of 30 mph / 13.4 m/s)
        let averageSpeedMetersPerSecond = 13.4
        let estimatedDuration = distance / averageSpeedMetersPerSecond
        
        // Add some traffic delay estimate (10% of duration)
        let trafficDelay = estimatedDuration * 0.1
        
        // Determine congestion level based on time of day
        let hour = Calendar.current.component(.hour, from: arrivalTime)
        let congestionLevel: CongestionLevel
        if (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19) {
            congestionLevel = .moderate
        } else {
            congestionLevel = .low
        }
        
        return RouteInfo(
            distance: distance,
            duration: estimatedDuration,
            trafficDelay: trafficDelay,
            geometry: nil,
            incidents: [],
            alternativeRoutes: [],
            congestionLevel: congestionLevel
        )
    }
    
    private func createFallbackWeather() -> WeatherData {
        // Default weather data - clear conditions, moderate temperature (21°C = 70°F)
        return WeatherData(
            temperature: 21.0, // Celsius
            feelsLike: 21.0,
            conditions: .clear,
            precipitation: 0.0,
            precipitationProbability: 0.0,
            windSpeed: 5.0, // m/s
            windDirection: 0,
            visibility: 10.0, // km
            humidity: 50,
            pressure: 1013.25,
            uvIndex: 5,
            cloudCoverage: 0,
            timestamp: Date(),
            alerts: []
        )
    }
    
    func saveTrip() async {
        guard let destination = selectedDestination else { return }
        
        // Debounce: prevent duplicate saves within 2 seconds
        let now = Date()
        guard now.timeIntervalSince(lastSaveTime) >= 2.0 else {
            print("[TripPlanner] Save request ignored - debounce active")
            return
        }
        
        // Prevent concurrent saves
        guard !isSaving else {
            print("[TripPlanner] Save request ignored - already saving")
            return
        }
        
        isSaving = true
        lastSaveTime = now
        
        // Check subscription limit before saving
        let canCreate = await tripStorageService.canCreateTrip(
            isSubscribed: subscriptionStatus.isSubscribed,
            subscriptionTier: subscriptionStatus.subscriptionTier
        )
        
        if !canCreate {
            // Show paywall for free users who have reached daily limit
            isSaving = false
            showPaywall = true
            return
        }
        
        let trip = Trip(
            origin: selectedOrigin,
            destination: destination,
            arrivalTime: arrivalTime,
            bufferMinutes: bufferMinutes,
            repeatDays: repeatDays
        )
        
        do {
            try await tripStorageService.saveTrip(trip)
            
            // Schedule in background to not block UI
            Task.detached { [leaveTimeScheduler] in
                await leaveTimeScheduler.scheduleTrip(trip)
            }
            
            analyticsService.trackEvent(.tripCreated(
                destination: destination.displayName,
                arrivalTime: arrivalTime
            ))
        } catch {
            setError(error)
        }
        
        isSaving = false
    }
    
    func refreshSubscriptionStatus() async {
        await subscriptionService.refreshSubscriptionStatus()
    }
}

#Preview {
    TripPlannerView(mode: .create)
}

