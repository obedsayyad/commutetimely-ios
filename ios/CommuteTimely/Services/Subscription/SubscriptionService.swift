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
    var loadingState: AnyPublisher<SubscriptionLoadingState, Never> { get }
    var availableProducts: AnyPublisher<[Product], Never> { get }
    
    func configure()
    func purchase(productId: String) async throws
    func restorePurchases() async throws
    func checkEntitlement(_ identifier: String) async -> Bool
    func refreshSubscriptionStatus() async
    func loadProducts() async
}

@MainActor
class SubscriptionService: SubscriptionServiceProtocol {
    private let authManager: AuthSessionController
    private let subscriptionManager: SubscriptionManager
    
    private let subscriptionStatusSubject = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus())
    private let loadingStateSubject = CurrentValueSubject<SubscriptionLoadingState, Never>(.idle)
    private let availableProductsSubject = CurrentValueSubject<[Product], Never>([])
    private var cancellables = Set<AnyCancellable>()
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    var loadingState: AnyPublisher<SubscriptionLoadingState, Never> {
        loadingStateSubject.eraseToAnyPublisher()
    }
    
    var availableProducts: AnyPublisher<[Product], Never> {
        availableProductsSubject.eraseToAnyPublisher()
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
            
        subscriptionManager.$loadingState
            .sink { [weak self] state in
                self?.loadingStateSubject.send(state)
            }
            .store(in: &cancellables)
            
        subscriptionManager.$availableProducts
            .sink { [weak self] products in
                self?.availableProductsSubject.send(products)
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
        // Purchases are currently disabled - paywall coming soon
        throw SubscriptionError.purchasesDisabled
    }
    
    func restorePurchases() async throws {
        // Restore purchases is currently disabled - paywall coming soon
        throw SubscriptionError.purchasesDisabled
    }
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        await subscriptionManager.checkEntitlement(identifier)
    }
    
    func refreshSubscriptionStatus() async {
        await subscriptionManager.updateSubscriptionStatus()
    }
    
    func loadProducts() async {
        await subscriptionManager.loadProducts()
    }
}

// MARK: - Mock Service

class MockSubscriptionService: SubscriptionServiceProtocol {
    private let subscriptionStatusSubject = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus())
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    var loadingState: AnyPublisher<SubscriptionLoadingState, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
    
    var availableProducts: AnyPublisher<[Product], Never> {
        Just([]).eraseToAnyPublisher()
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
    
    func loadProducts() async {
        // Mock: No-op
    }
}
