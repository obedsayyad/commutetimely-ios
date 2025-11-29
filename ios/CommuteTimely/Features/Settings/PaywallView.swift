//
// PaywallView.swift
// CommuteTimely
//
// StoreKit-based paywall for subscription purchases
//

import SwiftUI
import StoreKit
import Combine

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PaywallViewModel
    
    let analyticsService: AnalyticsServiceProtocol
    
    init(analyticsService: AnalyticsServiceProtocol = DIContainer.shared.analyticsService) {
        self.analyticsService = analyticsService
        _viewModel = StateObject(wrappedValue: PaywallViewModel(
            subscriptionService: DIContainer.shared.subscriptionService,
            analyticsService: analyticsService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(DesignTokens.Colors.primaryFallback())
                        
                        Text("Upgrade to Premium")
                            .font(DesignTokens.Typography.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited trips and advanced features")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                }
                    .padding(.top, DesignTokens.Spacing.xl)
                    
                    // Features
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        PaywallFeatureRow(icon: "infinity", text: "Unlimited trips")
                        PaywallFeatureRow(icon: "map.fill", text: "Advanced route predictions")
                        PaywallFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Alternative routes")
                        PaywallFeatureRow(icon: "bell.fill", text: "Smart notifications")
                }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    
                    // Products
                    if viewModel.isLoadingProducts {
                        ProgressView()
                            .padding()
                    } else if !viewModel.products.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(viewModel.products, id: \.id) { product in
                                ProductButton(
                                    product: product,
                                    isSelected: viewModel.selectedProductId == product.id,
                                    isPurchasing: viewModel.isPurchasing && viewModel.selectedProductId == product.id
                                ) {
                                    Task {
                                        await viewModel.purchase(productId: product.id)
                                    }
                                }
                            }
                }
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                    }
                    
                    // Restore button
                    Button {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(DesignTokens.Colors.primaryFallback())
                    }
                    .padding(.top, DesignTokens.Spacing.md)
                    
                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        analyticsService.trackEvent(.subscriptionStarted(tier: "dismissed"))
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            analyticsService.trackScreen("Paywall")
            Task {
                await viewModel.loadProducts()
            }
        }
        .onChange(of: viewModel.purchaseCompleted) { _, completed in
            if completed {
                analyticsService.trackEvent(.subscriptionStarted(tier: "premium"))
                dismiss()
            }
        }
    }
}

// MARK: - Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DesignTokens.Colors.primaryFallback())
                .frame(width: 24)
            Text(text)
                .font(DesignTokens.Typography.body)
            Spacer()
        }
    }
}

// MARK: - Product Button

private struct ProductButton: View {
    let product: Product
    let isSelected: Bool
    let isPurchasing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text(product.displayPrice)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                if isPurchasing {
                    ProgressView()
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
            }
            .padding()
            .background(isSelected ? DesignTokens.Colors.primaryFallback().opacity(0.1) : DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(isSelected ? DesignTokens.Colors.primaryFallback() : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isPurchasing)
    }
}

// MARK: - View Model

@MainActor
class PaywallViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isPurchasing = false
    @Published var selectedProductId: String?
    @Published var errorMessage: String?
    @Published var purchaseCompleted = false
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    // Product IDs - should match App Store Connect
    private let productIds = [
        "com.umer.CommuteTimely.premium.monthly",
        "com.umer.CommuteTimely.premium.yearly"
    ]
    
    init(subscriptionService: SubscriptionServiceProtocol, analyticsService: AnalyticsServiceProtocol) {
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
    }
    
    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
            
            if products.isEmpty {
                errorMessage = "No subscription products available"
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoadingProducts = false
    }
    
    func purchase(productId: String) async {
        isPurchasing = true
        selectedProductId = productId
        errorMessage = nil
        
        do {
            try await subscriptionService.purchase(productId: productId)
            purchaseCompleted = true
        } catch {
            if let subscriptionError = error as? SubscriptionError {
                switch subscriptionError {
                case .purchaseCancelled:
                    // Don't show error for cancellations
                    break
                default:
                    errorMessage = subscriptionError.localizedDescription
                }
            } else {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
        }
        
        isPurchasing = false
        selectedProductId = nil
    }
    
    func restorePurchases() async {
        errorMessage = nil
        
        do {
            try await subscriptionService.restorePurchases()
            errorMessage = "Purchases restored successfully!"
            
            // Check if user now has subscription
            let hasAccess = await subscriptionService.checkEntitlement("CommuteTimely Pro")
            if hasAccess {
                purchaseCompleted = true
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
