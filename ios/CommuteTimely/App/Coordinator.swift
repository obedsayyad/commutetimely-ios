//
// Coordinator.swift
// CommuteTimely
//
// Base coordinator protocol for navigation management
//

import Foundation
import SwiftUI
import Combine

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
    
    private let services: ServiceContainer
    private let userDefaults: UserDefaults
    
    init(services: ServiceContainer, userDefaults: UserDefaults = .standard) {
        self.services = services
        self.userDefaults = userDefaults
        
        // Determine initial route based on onboarding status
        let hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        self.currentRoute = hasCompletedOnboarding ? .main : .onboarding
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
}

