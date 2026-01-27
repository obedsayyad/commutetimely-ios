//
// NotificationPermissionView.swift
// CommuteTimely
//
// Notification permission request with clear explanation
//

import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void
    
    @State private var notificationsEnabled = false
    @State private var checkingStatus = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Progress indicator
                OnboardingProgressView(currentStep: 2, totalSteps: 2)
                    .padding(.top, DesignTokens.Spacing.xl)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.secondaryFallback().opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.secondaryFallback())
                }
                .padding(.bottom, DesignTokens.Spacing.md)
                
                // Title
                Text("Stay Notified")
                    .font(DesignTokens.Typography.title1)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                // Description
                Text("Get timely alerts so you never miss your departure window. We'll only notify you when it matters.")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Why we need this
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    PermissionReasonRow(
                        icon: "clock.badge.checkmark.fill",
                        text: "Know exactly when to leave for your destination"
                    )
                    
                    PermissionReasonRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Get alerts if traffic conditions change unexpectedly"
                    )
                    
                    PermissionReasonRow(
                        icon: "arrow.clockwise.circle.fill",
                        text: "Receive updated recommendations in real-time"
                    )
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Buttons
                VStack(spacing: DesignTokens.Spacing.md) {
                    if notificationsEnabled {
                        CTInfoCard(
                            title: "Notifications Enabled",
                            message: "You're all set! Let's get started.",
                            icon: "checkmark.circle.fill",
                            style: .success
                        )
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                    }
                    
                    CTButton(
                        notificationsEnabled ? "Complete Setup" : "Enable Notifications",
                        style: .primary,
                        isLoading: checkingStatus
                    ) {
                        if notificationsEnabled {
                            onContinue()
                        } else {
                            Task {
                                checkingStatus = true
                                await viewModel.requestNotificationPermission()
                                await checkNotificationStatus()
                                checkingStatus = false
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    
                    if !notificationsEnabled {
                        Button("Skip for Now") {
                            onContinue()
                        }
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
        }
        .background(DesignTokens.Colors.background)
        .onAppear {
            Task {
                await checkNotificationStatus()
            }
        }
    }
    
    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }
}

#Preview {
    let mockAuth = SupabaseMockAuthController()
    NotificationPermissionView(
        viewModel: OnboardingViewModel(
            locationService: MockLocationService(),
            notificationService: MockNotificationService(),
            analyticsService: MockAnalyticsService(),
            authManager: mockAuth
        ),
        onContinue: {}
    )
}

