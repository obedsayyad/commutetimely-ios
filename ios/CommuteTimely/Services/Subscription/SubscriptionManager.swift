//
// SubscriptionManager.swift
// CommuteTimely
//
// Native StoreKit 2 subscription management
//

import Foundation
import StoreKit
import Combine
import OSLog

enum SubscriptionLoadingState: Equatable {
    case idle
    case loading
    case success
    case failed(String)
}

@MainActor
class SubscriptionManager: ObservableObject {
    
    private static let logger = Logger(subsystem: "com.commutetimely.app", category: "SubscriptionManager")
    
    // MARK: - Published Properties
    
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var loadingState: SubscriptionLoadingState = .idle
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    private let productIds: Set<String> = [
        "com.develentcorp.commutetimely.pro.monthly",
        "com.develentcorp.commutetimely.pro.yearly",
        "com.develentcorp.commutetimely.pro.lifetime"
    ]
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Don't auto-load here. Let the service/viewmodel trigger it to allow for retry logic and better control.
        // We set state to idle initially.
        self.loadingState = .idle
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        guard loadingState != .loading else {
             Self.logger.info("Ignoring request to load products - already loading")
             return
        }
    
        self.loadingState = .loading
        Self.logger.info("Starting product load for IDs: \(self.productIds)")
        
        do {
            let products = try await Product.products(for: productIds)
            
            // Sort products: monthly, yearly, lifetime
            self.availableProducts = products.sorted { product1, product2 in
                if product1.id.contains("monthly") { return true }
                if product2.id.contains("monthly") { return false }
                if product1.id.contains("yearly") { return true }
                if product2.id.contains("yearly") { return false }
                return true
            }
            
            if self.availableProducts.isEmpty {
                 Self.logger.error("⚠️ No products returned from StoreKit. Common causes: Sandbox tester not set, Banking/Agreements missing, Bundle ID mismatch.")
                 self.loadingState = .failed("No products found. Please check network or configuration.")
            } else {
                 Self.logger.info("✅ Successfully loaded \(products.count) products")
                 self.loadingState = .success
            }
        } catch {
            Self.logger.error("❌ Failed to load products: \(error.localizedDescription)")
            self.loadingState = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async throws {
        print("[SubscriptionManager] 🛒 Initiating purchase for: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Finish the transaction
            await transaction.finish()
            
            print("[SubscriptionManager] ✅ Purchase successful: \(product.displayName)")
            
        case .userCancelled:
            print("[SubscriptionManager] ℹ️ User cancelled purchase")
            throw SubscriptionError.purchaseCancelled
            
        case .pending:
            print("[SubscriptionManager] ⏳ Purchase pending")
            throw SubscriptionError.paymentPending
            
        @unknown default:
            print("[SubscriptionManager] ❓ Unknown purchase result")
            throw SubscriptionError.purchaseFailed(NSError(domain: "Unknown", code: -1))
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        print("[SubscriptionManager] 🔄 Restoring purchases...")
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("[SubscriptionManager] ✅ Purchases restored successfully")
        } catch {
            print("[SubscriptionManager] ❌ Failed to restore purchases: \(error)")
            throw SubscriptionError.restoreFailed(error)
        }
    }
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        var status = SubscriptionStatus()
        var currentEntitlements: [String] = []
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Add to purchased products
                purchasedProductIDs.insert(transaction.productID)
                currentEntitlements.append(transaction.productID)
                
                // Check if it's an active subscription or lifetime purchase
                if transaction.productID.contains("lifetime") {
                    status.isSubscribed = true
                    status.subscriptionTier = .premium
                    status.expirationDate = nil // Lifetime never expires
                    print("[SubscriptionManager] 📱 Lifetime subscription active")
                } else if let expirationDate = transaction.expirationDate {
                    // It's a subscription with expiration
                    if expirationDate > Date() {
                        status.isSubscribed = true
                        status.subscriptionTier = .premium
                        status.expirationDate = expirationDate
                        
                        // Check if in trial period
                        if let offerType = transaction.offerType, offerType == .introductory {
                            status.isTrialing = true
                        }
                        
                        print("[SubscriptionManager] 📱 Active subscription until: \(expirationDate)")
                    }
                }
                
            } catch {
                print("[SubscriptionManager] ⚠️ Failed to verify transaction: \(error)")
            }
        }
        
        // Update published status
        self.subscriptionStatus = status
        
        if status.isSubscribed {
            print("[SubscriptionManager] ✅ User has active subscription")
        } else {
            print("[SubscriptionManager] ℹ️ No active subscription")
        }
    }
    
    // MARK: - Transaction Verification
    
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("[SubscriptionManager] ⚠️ Transaction verification failed")
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Updates Listener
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update subscription status on main actor
                    await self.updateSubscriptionStatus()
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                    print("[SubscriptionManager] 🔔 Transaction update processed: \(transaction.productID)")
                } catch {
                    print("[SubscriptionManager] ❌ Transaction update error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        await updateSubscriptionStatus()
        return subscriptionStatus.isSubscribed
    }
    
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseFailed(Error)
    case purchaseCancelled
    case paymentPending
    case verificationFailed
    case restoreFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .paymentPending:
            return "Payment is pending. Please check back later."
        case .verificationFailed:
            return "Failed to verify purchase"
        case .restoreFailed(let error):
            return "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
}
