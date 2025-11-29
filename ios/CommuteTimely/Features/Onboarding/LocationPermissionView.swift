//
// LocationPermissionView.swift
// CommuteTimely
//
// Location permission request with clear explanation
//

import SwiftUI
import CoreLocation
import Clerk

struct LocationPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void
    
    @State private var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Progress indicator
            OnboardingProgressView(currentStep: 1, totalSteps: 2)
                .padding(.top, DesignTokens.Spacing.xl)
            
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.primaryFallback().opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignTokens.Colors.primaryFallback())
            }
            .padding(.bottom, DesignTokens.Spacing.md)
            
            // Title
            Text("Enable Location")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            // Description
            Text("CommuteTimely needs your location to calculate accurate travel times and monitor traffic conditions.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            
            Spacer()
            
            // Why we need this
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                PermissionReasonRow(
                    icon: "map.fill",
                    text: "Calculate routes from your current location"
                )
                
                PermissionReasonRow(
                    icon: "arrow.triangle.swap",
                    text: "Get real-time traffic updates along your route"
                )
                
                PermissionReasonRow(
                    icon: "bell.badge.fill",
                    text: "Send timely notifications when you need to leave"
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            
            Spacer()
            
            // Buttons
            VStack(spacing: DesignTokens.Spacing.md) {
                if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                    CTInfoCard(
                        title: "Location Enabled",
                        message: "You're all set! Tap continue.",
                        icon: "checkmark.circle.fill",
                        style: .success
                    )
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                }
                
                CTButton(
                    authorizationStatus == .notDetermined ? "Enable Location" : "Continue",
                    style: .primary
                ) {
                    if authorizationStatus == .notDetermined {
                        viewModel.requestLocationPermission()
                    } else {
                        onContinue()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                
                if authorizationStatus == .denied {
                    CTInfoCard(
                        title: "Location Denied",
                        message: "Please enable location in Settings to use CommuteTimely",
                        icon: "exclamationmark.triangle.fill",
                        style: .warning
                    )
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Colors.background)
        .onReceive(viewModel.locationService.authorizationStatus) { status in
            authorizationStatus = status
        }
    }
}

// MARK: - Permission Reason Row

struct PermissionReasonRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Colors.primaryFallback())
                .frame(width: 30)
            
            Text(text)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Progress View

struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < currentStep ? DesignTokens.Colors.primaryFallback() : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }
}

#Preview {
    let mockAuth = ClerkMockProvider()
    LocationPermissionView(
        viewModel: OnboardingViewModel(
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            analyticsService: MockAnalyticsService(),
            authManager: mockAuth
        ),
        onContinue: {}
    )
}

