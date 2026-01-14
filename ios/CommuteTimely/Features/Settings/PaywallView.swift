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
    @StateObject private var viewModel = PaywallViewModel()
    
    init() {
        // No init params needed now, VM handles DI
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
                        switch viewModel.loadingState {
                        case .idle, .loading:
                            loadingView
                        case .success:
                            if viewModel.availableProducts.isEmpty {
                                errorView(message: "No products available")
                            } else {
                                productsView
                            }
                        case .failed(let errorMessage):
                            errorView(message: errorMessage)
                        }
                        
                        // Restore button
                        restoreButton
                        
                        // Legal footer
                        legalFooter
                    }
                    .padding()
                }
                
                // Loading overlay
                if viewModel.isPurchasing {
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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onChange(of: viewModel.isSubscribed) { isSubscribed in
            if isSubscribed {
                dismiss()
            }
        }
        .onAppear {
            viewModel.onViewAppear()
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
            ForEach(viewModel.availableProducts, id: \.id) { product in
                ProductCard(
                    product: product,
                    isPurchasing: viewModel.isPurchasing,
                    isSelected: viewModel.isRecommended(product)
                ) {
                    viewModel.purchase(product)
                }
            }
        }
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            viewModel.restorePurchases()
        } label: {
            Text("Restore Purchases")
                .font(.callout)
                .foregroundColor(.blue)
        }
        .disabled(viewModel.isPurchasing)
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
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            Text("Unable to load subscriptions")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.loadProducts()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .frame(height: 200)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
