//
// PaywallView.swift
// CommuteTimely
//
// Native StoreKit 2 paywall implementation
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    let analyticsService: AnalyticsServiceProtocol
    
    init(analyticsService: AnalyticsServiceProtocol = DIContainer.shared.analyticsService) {
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Features
                        featuresView
                        
                        // Products
                        if subscriptionManager.availableProducts.isEmpty {
                            loadingView
                        } else {
                            productsView
                        }
                        
                        // Restore button
                        restoreButton
                        
                        // Legal footer
                        legalFooter
                    }
                    .padding()
                }
                
                // Loading overlay
                if isPurchasing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Processing...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            analyticsService.trackScreen("Paywall")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("CommuteTimely Pro")
                .font(.title.bold())
            
            Text("Get personalized insights to understand your commute 3x better.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Features
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaywallFeatureRow(icon: "lock.open.fill", title: "Now", description: "Get full access to all features")
            PaywallFeatureRow(icon: "bell.badge.fill", title: "Early releases", description: "Get notified when early releases are available to test")
            PaywallFeatureRow(icon: "star.fill", title: "Premium support", description: "For your questions and feedback")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Products
    
    private var productsView: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                ProductCard(
                    product: product,
                    isPurchasing: isPurchasing,
                    isSelected: isRecommended(product)
                ) {
                    purchaseProduct(product)
                }
            }
        }
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            Text("Restore Purchases")
                .font(.callout)
                .foregroundColor(.blue)
        }
        .disabled(isPurchasing)
    }
    
    // MARK: - Legal Footer
    
    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text("By subscribing, you agree to our Terms of Use and Privacy Policy")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: AppConfiguration.privacyPolicyURL)!)
                Text("•")
                Link("Terms of Use", destination: URL(string: AppConfiguration.termsOfUseURL)!)
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading subscription options...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    // MARK: - Actions
    
    private func purchaseProduct(_ product: Product) {
        Task {
            isPurchasing = true
            
            do {
                try await subscriptionManager.purchase(product)
                
                // Track purchase
                analyticsService.trackEvent(.subscriptionStarted(tier: "premium"))
                
                // Dismiss on success
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isPurchasing = false
        }
    }
    
    private func restorePurchases() {
        Task {
            isPurchasing = true
            
            do {
                try await subscriptionManager.restorePurchases()
                
                if subscriptionManager.subscriptionStatus.isSubscribed {
                    dismiss()
                } else {
                    errorMessage = "No previous purchases found"
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isPurchasing = false
        }
    }
    
    private func isRecommended(_ product: Product) -> Bool {
        return product.id.contains("yearly")
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let isPurchasing: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(productTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if isSelected {
                            Text("RECOMMENDED")
                                .font(.caption2.bold())
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let description = productDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.white : Color.blue, lineWidth: isSelected ? 3 : 0)
                    )
            )
        }
        .disabled(isPurchasing)
        .buttonStyle(.plain)
    }
    
    private var productTitle: String {
        if product.id.contains("monthly") {
            return "Monthly"
        } else if product.id.contains("yearly") {
            return "Yearly"
        } else if product.id.contains("lifetime") {
            return "Lifetime"
        }
        return product.displayName
    }
    
    private var productDescription: String? {
        if product.id.contains("yearly") {
            return "Best value - Save 40%"
        } else if product.id.contains("lifetime") {
            return "One-time purchase"
        }
        return nil
    }
}

// MARK: - Paywall Feature Row

struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
