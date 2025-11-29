//
//  CommuteTimelyApp.swift
//  CommuteTimely
//
//  Production-ready app entry point with coordinator-based navigation
//

import SwiftUI
import Combine
import Clerk

@main
struct CommuteTimelyApp: App {
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var themeManager: ThemeManager
    private let services: ServiceContainer
    @State private var clerk = Clerk.shared
    
    init() {
        // Initialize services
        let serviceContainer = DIContainer.shared
        self.services = serviceContainer
        
        // Initialize coordinator with services
        _coordinator = StateObject(wrappedValue: AppCoordinator(services: serviceContainer))
        
        // Initialize theme manager
        _themeManager = StateObject(wrappedValue: serviceContainer.themeManager)
        
        // Configure subscription service
        serviceContainer.subscriptionService.configure()
        configureClerkIfNeeded()
        
        #if DEBUG
        print("[App] Subscription service configured in DEBUG mode")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environmentObject(themeManager)
                .environment(\.clerk, clerk)
                .applyTheme(themeManager)
                .onAppear {
                    setupBackgroundTasks()
                }
                .task {
                    await loadClerkIfNeeded()
                    await services.leaveTimeScheduler.handleSignificantLocationChange()
                    // Update personalized notification schedule if needed
                    await services.personalizedNotificationScheduler.updateScheduleIfNeeded()
                }
        }
    }
    
    private func setupBackgroundTasks() {
        // Register background tasks for prediction updates
        services.notificationService.registerBackgroundTasks()
    }
    
    private func configureClerkIfNeeded() {
        guard !AppConfiguration.useClerkMock else {
            #if DEBUG
            print("[Auth] Skipping Clerk configuration because mock mode is enabled")
            #endif
            return
        }
        
        clerk.configure(publishableKey: AppConfiguration.clerkPublishableKey)
        // Ensure Associated Domains contain: webcredentials:\(AppConfiguration.clerkFrontendAPI)
    }
    
    private func loadClerkIfNeeded() async {
        guard !AppConfiguration.useClerkMock else { return }
        guard !clerk.isLoaded else { return }
        
        do {
            try await clerk.load()
        } catch {
            #if DEBUG
            print("[Auth] Clerk failed to load: \(error)")
            #endif
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    private let authManager = DIContainer.shared.authManager
    private let personalizedNotificationScheduler = DIContainer.shared.personalizedNotificationScheduler
    
    var body: some View {
        Group {
            switch coordinator.currentRoute {
            case .onboarding:
                OnboardingCoordinatorView()
            case .main:
                MainTabView()
            default:
                MainTabView()
            }
        }
        .task {
            // Observe auth state changes
            for await state in authManager.authStatePublisher.values {
                await handleAuthStateChange(state)
            }
        }
    }
    
    private func handleAuthStateChange(_ state: AuthSessionState) async {
        switch state {
        case .signedOut:
            // Cancel all personalized notifications on sign out
            await personalizedNotificationScheduler.cancelAllPersonalizedNotifications()
            
            // Update preferences to disable personalized notifications
            let preferencesService = DIContainer.shared.userPreferencesService
            var preferences = await preferencesService.loadPreferences()
            preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
            try? await preferencesService.updatePreferences(preferences)
            
        case .signedIn(let user):
            // On sign in, check if personalized notifications are enabled and reschedule
            let preferencesService = DIContainer.shared.userPreferencesService
            let preferences = await preferencesService.loadPreferences()
            
            if preferences.notificationSettings.personalizedDailyNotificationsEnabled {
                // Reschedule with new user's firstName
                let firstName = user.firstName ?? "Friend"
                do {
                    try await personalizedNotificationScheduler.scheduleDailyNotifications(firstName: firstName)
                } catch {
                    print("[App] Failed to reschedule personalized notifications after sign in: \(error)")
                }
            }
        }
    }
}
