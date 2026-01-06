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
    @State private var offerings: Offerings?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
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
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if let offering = offerings?.current {
                    paywallView(offering: offering)
                } else {
                    noOfferingView
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadOfferings()
        }
        .onAppear {
            analyticsService.trackScreen("Paywall")
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading subscription options...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Unable to Load Subscriptions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        await loadOfferings()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noOfferingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("No Subscription Options")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Subscription options are not currently available. Please try again later.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func paywallView(offering: Offering) -> some View {
        RevenueCatUI.PaywallView(offering: offering)
            .onPurchaseCompleted { customerInfo in
                print("[PaywallView] ✅ Purchase completed successfully")
                analyticsService.trackEvent(.subscriptionStarted(tier: "premium"))
                
                // Refresh subscription status to update all UI immediately
                Task {
                    await subscriptionService.refreshSubscriptionStatus()
                }
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                print("[PaywallView] ✅ Restore completed")
                
                // Refresh subscription status
                Task {
                    await subscriptionService.refreshSubscriptionStatus()
                }
                
                // Check if user now has entitlements
                if !customerInfo.entitlements.active.isEmpty {
                    print("[PaywallView] ✅ Active entitlements found after restore")
                    dismiss()
                } else {
                    print("[PaywallView] ⚠️ No active entitlements found after restore")
                }
            }
            .onPurchaseCancelled {
                print("[PaywallView] ℹ️ Purchase cancelled by user")
            }
    }
    
    // MARK: - Data Loading
    
    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        
        print("[PaywallView] 🔄 Loading offerings...")
        
        do {
            offerings = try await subscriptionService.getCurrentOfferings()
            
            if let current = offerings?.current {
                print("[PaywallView] ✅ Loaded current offering: \(current.identifier)")
                print("[PaywallView] 📦 Available packages: \(current.availablePackages.count)")
                
                for package in current.availablePackages {
                    print("[PaywallView]   - \(package.identifier): \(package.storeProduct.localizedTitle) (\(package.storeProduct.localizedPriceString))")
                }
            } else {
                print("[PaywallView] ⚠️ No current offering found")
                errorMessage = """
                No subscription options are currently configured.
                
                Please ensure:
                • RevenueCat Dashboard has an offering marked as "Current"
                • Products are attached to the offering
                • App Store Connect products are properly configured
                """
            }
            
            isLoading = false
        } catch {
            print("[PaywallView] ❌ Failed to load offerings: \(error)")
            
            isLoading = false
            
            // Provide user-friendly error messages
            if let rcError = error as? ErrorCode {
                switch rcError {
                case .configurationError:
                    errorMessage = """
                    Configuration Error (Error 23)
                    
                    There's an issue with the subscription setup. Please contact support.
                    
                    Technical details: \(rcError.localizedDescription)
                    """
                case .networkError:
                    errorMessage = """
                    Network Error
                    
                    Unable to connect to the subscription service. Please check your internet connection and try again.
                    """
                case .storeProblemError:
                    errorMessage = """
                    App Store Error
                    
                    There's a problem connecting to the App Store. Please try again later.
                    """
                default:
                    errorMessage = """
                    Error Loading Subscriptions
                    
                    \(rcError.localizedDescription)
                    
                    Error code: \(rcError.errorCode)
                    """
                }
            } else {
                errorMessage = """
                Unexpected Error
                
                \(error.localizedDescription)
                
                Please try again or contact support if the problem persists.
                """
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
