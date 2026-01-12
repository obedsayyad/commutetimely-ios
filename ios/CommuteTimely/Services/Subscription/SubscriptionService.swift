//
// SubscriptionService.swift
// CommuteTimely
//
// StoreKit 2-based subscription service with Supabase integration
//

import Foundation
import Combine
import StoreKit

protocol SubscriptionServiceProtocol {
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> { get }
    
    func configure()
    func purchase(productId: String) async throws
    func restorePurchases() async throws
    func checkEntitlement(_ identifier: String) async -> Bool
    func refreshSubscriptionStatus() async
}

@MainActor
class SubscriptionService: SubscriptionServiceProtocol {
    private let authManager: AuthSessionController
    private let subscriptionManager: SubscriptionManager
    
    private let subscriptionStatusSubject = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus())
    private var cancellables = Set<AnyCancellable>()
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    init(authManager: AuthSessionController) {
        self.authManager = authManager
        self.subscriptionManager = SubscriptionManager()
        
        // Observe subscription manager status changes
        subscriptionManager.$subscriptionStatus
            .sink { [weak self] status in
                self?.subscriptionStatusSubject.send(status)
            }
            .store(in: &cancellables)
    }
    
    func configure() {
        // Load products and check subscription status
        Task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.updateSubscriptionStatus()
        }
    }
    
    func purchase(productId: String) async throws {
        guard let product = subscriptionManager.availableProducts.first(where: { $0.id == productId }) else {
            throw SubscriptionError.productNotFound
        }
        
        try await subscriptionManager.purchase(product)
    }
    
    func restorePurchases() async throws {
        try await subscriptionManager.restorePurchases()
    }
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        await subscriptionManager.checkEntitlement(identifier)
    }
    
    func refreshSubscriptionStatus() async {
        await subscriptionManager.updateSubscriptionStatus()
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
