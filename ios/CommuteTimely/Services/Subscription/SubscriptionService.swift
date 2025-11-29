//
// SubscriptionService.swift
// CommuteTimely
//
// StoreKit 2-based subscription service with Clerk integration
//

import Foundation
import Combine
import StoreKit
import Clerk

protocol SubscriptionServiceProtocol {
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> { get }
    
    func configure()
    func purchase(productId: String) async throws
    func restorePurchases() async throws
    func checkEntitlement(_ identifier: String) async -> Bool
    func refreshSubscriptionStatus() async
}

@MainActor
class SubscriptionService: NSObject, SubscriptionServiceProtocol {
    private let authManager: AuthSessionController
    private let entitlementIdentifier = "CommuteTimely Pro"
    
    private let subscriptionStatusSubject = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus())
    private var updateListenerTask: Task<Void, Error>?
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    init(authManager: AuthSessionController) {
        self.authManager = authManager
        super.init()
    }
    
    func configure() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load initial subscription status
        Task {
            await refreshSubscriptionStatus()
        }
    }
    
    func purchase(productId: String) async throws {
        guard let product = try? await Product.products(for: [productId]).first else {
            throw SubscriptionError.productNotFound
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .userCancelled:
                throw SubscriptionError.purchaseCancelled
            case .pending:
                throw SubscriptionError.paymentPending
            @unknown default:
                throw SubscriptionError.purchaseFailed(NSError(domain: "SubscriptionService", code: -1))
            }
        } catch {
            if error is SubscriptionError {
                throw error
            }
            throw SubscriptionError.purchaseFailed(error)
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshSubscriptionStatus()
    }
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        await refreshSubscriptionStatus()
        return subscriptionStatusSubject.value.isSubscribed
    }
    
    func refreshSubscriptionStatus() async {
        var status = SubscriptionStatus()
        
        // Check StoreKit subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                // Check if this is our premium product
                if transaction.productID.contains("premium") || transaction.productID.contains("pro") {
                    status.isSubscribed = true
                    status.subscriptionTier = .premium
                    status.expirationDate = transaction.expirationDate
                    
                    // Check if in trial period
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                        status.isTrialing = daysUntilExpiration <= 7
                    }
                    break
                }
            } catch {
                continue
            }
        }
        
        // Also check Clerk user metadata for subscription status
        if let clerkUser = Clerk.shared.user,
           let subscriptionData = clerkUser.publicMetadata?["subscription"] as? [String: Any] {
            if let isSubscribed = subscriptionData["isSubscribed"] as? Bool, isSubscribed {
                status.isSubscribed = true
                if let tierString = subscriptionData["tier"] as? String,
                   let tier = SubscriptionTier(rawValue: tierString) {
                    status.subscriptionTier = tier
                }
                if let expirationTimestamp = subscriptionData["expirationDate"] as? TimeInterval {
                    status.expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
                }
            }
        }
        
        subscriptionStatusSubject.send(status)
        
        // Log subscription status update
        if status.isSubscribed {
            print("[SubscriptionService] Subscription status updated: Active")
        }
    }
    
    // MARK: - Private Helpers
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self?.refreshSubscriptionStatus()
                } catch {
                    continue
                }
            }
        }
    }
    
    private static nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
}

// MARK: - Errors

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

// MARK: - Mock Service

class MockSubscriptionService: SubscriptionServiceProtocol {
    private let subscriptionStatusSubject = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus())
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    func configure() {}
    
    func purchase(productId: String) async throws {
        // Mock: Set as subscribed for testing
        let status = SubscriptionStatus(
            isSubscribed: true,
            subscriptionTier: .premium,
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            isTrialing: false
        )
        subscriptionStatusSubject.send(status)
    }
    
    func restorePurchases() async throws {
        // Mock: No-op
    }
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        return subscriptionStatusSubject.value.isSubscribed
    }
    
    func refreshSubscriptionStatus() async {
        // Mock: No-op
    }
}

