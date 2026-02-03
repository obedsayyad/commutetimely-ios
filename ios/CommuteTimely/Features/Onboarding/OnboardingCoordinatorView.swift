//
// OnboardingCoordinatorView.swift
// CommuteTimely
//
// Coordinator view for onboarding flow
//

import SwiftUI
import Combine
import CoreLocation

struct OnboardingCoordinatorView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel = OnboardingViewModel(
        locationService: DIContainer.shared.locationService,
        notificationService: DIContainer.shared.notificationService,
        analyticsService: DIContainer.shared.analyticsService,
        authManager: DIContainer.shared.authManager
    )
    
    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(onContinue: { viewModel.nextStep() })
            case .locationPermission:
                LocationPermissionView(
                    viewModel: viewModel,
                    onContinue: { 
                        // Only allow continuing if we've actually requested permission
                        // or if status is already determined
                        if viewModel.hasUserSeenLocationPermissionPrompt() {
                            viewModel.nextStep() 
                        }
                    }
                )
            case .notificationPermission:
                NotificationPermissionView(
                    viewModel: viewModel,
                    onContinue: { viewModel.nextStep() }
                )
            case .optionalAuth:
                OnboardingAuthView(
                    authManager: viewModel.authManager,
                    onContinue: { viewModel.nextStep() },
                    onSkip: { viewModel.skipAuth() }
                )
            case .completed:
                Color.clear.onAppear {
                    appCoordinator.completeOnboarding()
                }
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        .animation(DesignTokens.Animation.adaptive(DesignTokens.Animation.springSmooth), value: viewModel.currentStep)
    }
}

// MARK: - Onboarding ViewModel

@MainActor
class OnboardingViewModel: BaseViewModel {
    @Published var currentStep: OnboardingStep = .welcome
    @Published private(set) var locationPermissionRequested = false
    @Published var currentAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    let locationService: LocationServiceProtocol
    let authManager: AuthSessionController
    private let notificationService: NotificationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    init(
        locationService: LocationServiceProtocol,
        notificationService: NotificationServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        authManager: AuthSessionController
    ) {
        self.locationService = locationService
        self.notificationService = notificationService
        self.analyticsService = analyticsService
        self.authManager = authManager
        super.init()
        
        // Subscribe to auth status
        locationService.authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentAuthorizationStatus)
    }
    
    func nextStep() {
        withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.springSmooth)) {
            switch currentStep {
            case .welcome:
                currentStep = .locationPermission
            case .locationPermission:
                currentStep = .notificationPermission
            case .notificationPermission:
                currentStep = .optionalAuth
            case .optionalAuth:
                currentStep = .completed
                analyticsService.trackEvent(.onboardingCompleted)
            case .completed:
                break
            }
        }
    }
    
    func skipAuth() {
        withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.springSmooth)) {
            currentStep = .completed
            analyticsService.trackEvent(.onboardingCompleted)
            analyticsService.trackEvent(.onboardingAuthSkipped)
        }
    }
    
    func requestLocationPermission() {
        locationService.requestAlwaysAuthorization()
        locationPermissionRequested = true
    }
    
    func hasUserSeenLocationPermissionPrompt() -> Bool {
        return locationPermissionRequested || 
               currentAuthorizationStatus != .notDetermined
    }
    
    func requestNotificationPermission() async {
        do {
            let granted = try await notificationService.requestAuthorization()
            if granted {
                print("Notifications authorized")
            }
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }
}

enum OnboardingStep {
    case welcome
    case locationPermission
    case notificationPermission
    case optionalAuth
    case completed
}

// MARK: - Onboarding Auth View

struct OnboardingAuthView: View {
    @ObservedObject var authManager: AuthSessionController
    let onContinue: () -> Void
    let onSkip: () -> Void
    @State private var showingAuthLanding = false
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.primary)
                .padding(.bottom, DesignTokens.Spacing.lg)
            
            // Title
            Text("Back up your trips")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Description
            Text("Sign in to sync your trips across all your devices. Your data stays private and secure.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            
            Spacer()
            
            // Sign in button
            CTButton("Sign In", style: .primary) {
                showingAuthLanding = true
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // Skip button
            Button {
                onSkip()
            } label: {
                Text("Maybe later")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .padding()
        .sheet(isPresented: $showingAuthLanding) {
            AuthLandingView(authManager: authManager)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                onContinue()
            }
        }
    }
}

