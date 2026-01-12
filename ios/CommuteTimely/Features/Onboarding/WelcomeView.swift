//
// WelcomeView.swift
// CommuteTimely
//
// Smart Onboarding Wizard with permission requests
//

import SwiftUI
import Combine
import CoreLocation

struct WelcomeView: View {
    let onContinue: () -> Void
    
    @State private var currentTab = 0
    @StateObject private var viewModel = WelcomeViewModel()
    
    var body: some View {
        ZStack {
            // Background mesh gradient (Premium UI)
            DesignTokens.Gradients.primaryMesh
                .ignoresSafeArea()
            
            VStack {
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index == currentTab ? DesignTokens.Colors.primaryFallback() : Color.gray.opacity(0.3))
                            .frame(width: index == currentTab ? 24 : 8, height: 8)
                            .animation(DesignTokens.Animation.spring, value: currentTab)
                    }
                }
                .padding(.top, DesignTokens.Spacing.xl)
                
                TabView(selection: $currentTab) {
                    welcomeStep.tag(0)
                    locationStep.tag(1)
                    calendarStep.tag(2)
                    notificationStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(DesignTokens.Animation.standard, value: currentTab)
            }
        }
    }
    
    // MARK: - Steps
    
    private var welcomeStep: some View {
        OnboardingStepView(
            icon: "clock.arrow.circlepath",
            title: "CommuteTimely",
            subtitle: "Never miss your arrival time again.",
            description: "AI-powered departure alerts specifically designed for your daily commute.",
            primaryButtonTitle: "Start Setup",
            secondaryButtonTitle: nil,
            onPrimary: { withAnimation { currentTab += 1 } },
            onSecondary: nil
        )
    }
    
    private var locationStep: some View {
        OnboardingStepView(
            icon: "location.fill",
            title: "Smart Location",
            subtitle: "Where are you starting from?",
            description: "We use your location to calculate precise travel times and traffic delays in real-time.",
            primaryButtonTitle: viewModel.locationAuthorized ? "Allowed ✓" : "Allow Location Access",
            secondaryButtonTitle: "Skip for now",
            onPrimary: {
                Task {
                    await viewModel.requestLocationAccess()
                    withAnimation { currentTab += 1 }
                }
            },
            onSecondary: { withAnimation { currentTab += 1 } }
        )
    }
    
    private var calendarStep: some View {
        OnboardingStepView(
            icon: "calendar.badge.clock",
            title: "Auto-Sync",
            subtitle: "Connect your schedule",
            description: "Automatically see departure times for your upcoming meetings and work events.",
            primaryButtonTitle: viewModel.calendarAuthorized ? "Connected ✓" : "Connect Calendar",
            secondaryButtonTitle: "Skip",
            onPrimary: {
                Task {
                    await viewModel.requestCalendarAccess()
                    withAnimation { currentTab += 1 }
                }
            },
            onSecondary: { withAnimation { currentTab += 1 } }
        )
    }
    
    private var notificationStep: some View {
        OnboardingStepView(
            icon: "bell.badge.fill",
            title: "Critical Alerts",
            subtitle: "Never be late",
            description: "Enable notifications to get 'Leave Now' alerts that break through focus modes.",
            primaryButtonTitle: "Enable Alerts & Finish",
            secondaryButtonTitle: "Maybe Later",
            onPrimary: {
                Task {
                    await viewModel.requestNotificationAccess()
                    onContinue()
                }
            },
            onSecondary: { onContinue() }
        )
    }
}

// MARK: - Reusable Step View

struct OnboardingStepView: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.surfaceElevated)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(DesignTokens.Colors.primaryFallback())
            }
            .padding(.bottom, DesignTokens.Spacing.md)
            
            // Text
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                Text(description)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.top, DesignTokens.Spacing.sm)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: DesignTokens.Spacing.md) {
                CTButton(primaryButtonTitle, style: .primary) {
                    HapticManager.shared.tap()
                    onPrimary()
                }
                
                if let secondaryTitle = secondaryButtonTitle, let onSecondary = onSecondary {
                    Button(action: {
                        HapticManager.shared.tap()
                        onSecondary()
                    }) {
                        Text(secondaryTitle)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .padding()
    }
}

// MARK: - ViewModel

@MainActor
class WelcomeViewModel: ObservableObject {
    @Published var locationAuthorized = false
    @Published var calendarAuthorized = false
    
    func requestLocationAccess() async {
        let service = DIContainer.shared.locationService
        service.requestWhenInUseAuthorization()
        locationAuthorized = true
    }
    
    func requestCalendarAccess() async {
        let service = DIContainer.shared.calendarService
        do {
            _ = try await service.requestAccess()
            calendarAuthorized = true
        } catch {
            print("Calendar permission denied")
        }
    }
    
    func requestNotificationAccess() async {
        let service = DIContainer.shared.notificationService
        do {
            _ = try await service.requestAuthorization()
        } catch {
            print("Notification permission denied")
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
