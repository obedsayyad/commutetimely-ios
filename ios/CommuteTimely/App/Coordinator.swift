//
// Coordinator.swift
// CommuteTimely
//
// Base coordinator protocol for navigation management
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - App Routes

enum AppRoute {
    case onboarding
    case main
    case tripPlanner(mode: TripPlannerMode)
    case tripDetail(trip: Trip)
    case settings
    case subscription
}

enum TripPlannerMode: Equatable {
    case create
    case edit(Trip)
}

// MARK: - App Coordinator

@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentRoute: AppRoute = .onboarding
    @Published var navigationPath: [AppRoute] = []
    @Published var showingSheet: AppRoute?
    @Published var isNavigating: Bool = false
    @Published var navigatingTripId: UUID?
    
    private let services: ServiceContainer
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    init(services: ServiceContainer, userDefaults: UserDefaults = .standard) {
        self.services = services
        self.userDefaults = userDefaults
        
        // Determine initial route based on onboarding status
        let hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        self.currentRoute = hasCompletedOnboarding ? .main : .onboarding
        
        // Set up notification observers for trip navigation
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Observe Start Trip action from notification
        NotificationCenter.default.publisher(for: .startTripNavigation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStartTripNavigation(notification)
            }
            .store(in: &cancellables)
        
        // Observe Declined Trip action
        NotificationCenter.default.publisher(for: .declinedTripNavigation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleDeclinedTripNavigation(notification)
            }
            .store(in: &cancellables)
        
        // Observe Open Navigation action
        NotificationCenter.default.publisher(for: .openNavigation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleOpenNavigation(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleStartTripNavigation(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdString) else {
            print("[Coordinator] Invalid trip ID in notification")
            return
        }
        
        print("[Coordinator] Starting trip navigation for trip: \(tripId)")
        isNavigating = true
        navigatingTripId = tripId
        
        // Start Dynamic Island navigation mode
        Task {
            // Get current location
            let locationService = services.locationService
            if let currentLocation = try? await locationService.getCurrentLocation() {
                let coordinate = Coordinate(
                    latitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude
                )
                
                // Start navigation mode on Dynamic Island
                await services.commuteActivityManager.startNavigationMode(
                    for: tripId,
                    currentLocation: coordinate
                )
                
                print("[Coordinator] Dynamic Island navigation mode started")
            } else {
                print("[Coordinator] Could not get current location for navigation")
            }
        }
    }
    
    private func handleDeclinedTripNavigation(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String else { return }
        print("[Coordinator] User declined trip navigation for: \(tripIdString)")
        isNavigating = false
        navigatingTripId = nil
    }
    
    private func handleOpenNavigation(_ notification: Notification) {
        guard let tripIdString = notification.userInfo?["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdString) else { return }
        
        print("[Coordinator] Opening navigation for trip: \(tripId)")
        
        // Fetch trip and open Maps
        Task {
            let trips = await services.tripStorageService.fetchTrips()
            guard let trip = trips.first(where: { $0.id == tripId }) else { return }
            
            let destination = trip.destination.coordinate
            let urlString = "maps://?daddr=\(destination.latitude),\(destination.longitude)"
            if let url = URL(string: urlString) {
                await UIApplication.shared.open(url)
            }
        }
    }
    
    func navigate(to route: AppRoute) {
        navigationPath.append(route)
    }
    
    func presentSheet(_ route: AppRoute) {
        showingSheet = route
    }
    
    func dismissSheet() {
        showingSheet = nil
    }
    
    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func popToRoot() {
        navigationPath.removeAll()
    }
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
        currentRoute = .main
    }
    
    func resetOnboarding() {
        userDefaults.set(false, forKey: "hasCompletedOnboarding")
        currentRoute = .onboarding
        navigationPath.removeAll()
    }
    
    func stopNavigation() {
        isNavigating = false
        if let tripId = navigatingTripId {
            Task {
                await services.commuteActivityManager.endActivity(for: tripId)
            }
        }
        navigatingTripId = nil
    }
}
