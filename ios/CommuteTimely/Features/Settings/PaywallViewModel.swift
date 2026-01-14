//
// PaywallViewModel.swift
// CommuteTimely
//
// ViewModel for PaywallView to manage subscription state and logic
//

import Foundation
import Combine
import StoreKit

@MainActor
class PaywallViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var loadingState: SubscriptionLoadingState = .idle
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isSubscribed: Bool = false
    
    // MARK: - Dependencies
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(subscriptionService: SubscriptionServiceProtocol = DIContainer.shared.subscriptionService,
         analyticsService: AnalyticsServiceProtocol = DIContainer.shared.analyticsService) {
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind loading state
        subscriptionService.loadingState
            .receive(on: DispatchQueue.main)
            .assign(to: &$loadingState)
        
        // Bind products
        subscriptionService.availableProducts
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableProducts)
            
        // Bind subscription status
        subscriptionService.subscriptionStatus
            .map { $0.isSubscribed }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSubscribed)
    }
    
    // MARK: - Actions
    
    func onViewAppear() {
        analyticsService.trackScreen("Paywall")
        
        if loadingState == .idle || availableProducts.isEmpty {
            loadProducts()
        }
    }
    
    func loadProducts() {
        Task {
            await subscriptionService.loadProducts()
        }
    }
    
    func purchase(_ product: Product) {
        Task {
            isPurchasing = true
            
            do {
                try await subscriptionService.purchase(productId: product.id)
                analyticsService.trackEvent(.subscriptionStarted(tier: "premium"))
                // Success is handled via subscriptionStatus binding
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isPurchasing = false
        }
    }
    
    func restorePurchases() {
        Task {
            isPurchasing = true
            
            do {
                try await subscriptionService.restorePurchases()
                
                // Check if restoration actually resulted in a subscription
                // Since checkEntitlement is async, we can check status via binding or direct check
                // For immediate user feedback:
                if isSubscribed {
                   // Success usually handled by view dismissing or updating UI
                } else {
                   // Ideally we check if we found *any* transaction, but simplicity:
                   if !isSubscribed {
                        errorMessage = "No active subscriptions found to restore."
                        showError = true
                   }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isPurchasing = false
        }
    }
    
    func isRecommended(_ product: Product) -> Bool {
        return product.id.contains("yearly")
    }
}
