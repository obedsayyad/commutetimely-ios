//
// PaywallView.swift
// CommuteTimely
//
// RevenueCat-based paywall for subscription purchases
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    let analyticsService: AnalyticsServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    
    init(
        analyticsService: AnalyticsServiceProtocol = DIContainer.shared.analyticsService,
        subscriptionService: SubscriptionServiceProtocol = DIContainer.shared.subscriptionService
    ) {
        self.analyticsService = analyticsService
        self.subscriptionService = subscriptionService
    }
    
    var body: some View {
        RevenueCatUI.PaywallView()
            .onPurchaseCompleted { customerInfo in
                analyticsService.trackEvent(.subscriptionStarted(tier: "premium"))
                // Refresh subscription status to update all UI immediately
                Task {
                    await subscriptionService.refreshSubscriptionStatus()
                }
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                // Refresh subscription status
                Task {
                    await subscriptionService.refreshSubscriptionStatus()
                }
                // Check if user now has entitlements
                if !customerInfo.entitlements.active.isEmpty {
                    dismiss()
                }
            }
            .onAppear {
                analyticsService.trackScreen("Paywall")
            }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
