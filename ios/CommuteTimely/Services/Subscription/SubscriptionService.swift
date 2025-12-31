//
// SubscriptionService.swift
// CommuteTimely
//
// RevenueCat-based subscription service with Supabase integration
//

import Foundation
import Combine
import RevenueCat

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
    private var customerInfoListenerTask: Task<Void, Never>?
    
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never> {
        subscriptionStatusSubject.eraseToAnyPublisher()
    }
    
    init(authManager: AuthSessionController) {
        self.authManager = authManager
        super.init()
    }
    
    func configure() {
        // Sync RevenueCat user ID with Supabase auth
        Task {
            await syncRevenueCatUser()
        }
        
        // Load initial subscription status
        Task {
            await refreshSubscriptionStatus()
        }
        
        // Listen for customer info updates
        customerInfoListenerTask = Task { [weak self] in
            await self?.listenForCustomerInfoUpdates()
        }
    }
    
    func purchase(productId: String) async throws {
        do {
            guard let package = try await getPackage(for: productId) else {
                throw SubscriptionError.productNotFound
            }
            
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            
            // Update subscription status from customer info
            await updateStatusFromCustomerInfo(customerInfo)
        } catch {
            if let rcError = error as? ErrorCode {
                switch rcError {
                case .purchaseCancelledError:
                    throw SubscriptionError.purchaseCancelled
                case .paymentPendingError:
                    throw SubscriptionError.paymentPending
                default:
                    throw SubscriptionError.purchaseFailed(error)
                }
            } else {
                throw SubscriptionError.purchaseFailed(error)
            }
        }
    }
    
    func restorePurchases() async throws {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await updateStatusFromCustomerInfo(customerInfo)
        } catch {
            throw SubscriptionError.restoreFailed(error)
        }
    }
    
    func checkEntitlement(_ identifier: String) async -> Bool {
        await refreshSubscriptionStatus()
        return subscriptionStatusSubject.value.isSubscribed
    }
    
    func refreshSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await updateStatusFromCustomerInfo(customerInfo)
        } catch {
            print("[SubscriptionService] Failed to refresh subscription status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func syncRevenueCatUser() async {
        // Link RevenueCat user ID with Supabase auth user ID
        if let userId = authManager.currentUser?.id {
            do {
                let (_, _) = try await Purchases.shared.logIn(userId)
                print("[SubscriptionService] RevenueCat logged in with user ID: \(userId)")
            } catch {
                print("[SubscriptionService] Failed to log in RevenueCat: \(error.localizedDescription)")
            }
        } else {
            // Log out RevenueCat if user is signed out
            do {
                let _ = try await Purchases.shared.logOut()
                print("[SubscriptionService] RevenueCat logged out")
            } catch {
                print("[SubscriptionService] Failed to log out RevenueCat: \(error.localizedDescription)")
            }
        }
    }
    
    private func getPackage(for productId: String) async throws -> Package? {
        let offerings = try await Purchases.shared.offerings()
        return offerings.current?.availablePackages.first { $0.storeProduct.productIdentifier == productId }
    }
    
    private func updateStatusFromCustomerInfo(_ customerInfo: CustomerInfo) async {
        var status = SubscriptionStatus()
        
        // Check premium entitlement
        if let entitlement = customerInfo.entitlements[entitlementIdentifier],
           entitlement.isActive {
            status.isSubscribed = true
            status.subscriptionTier = .premium
            status.expirationDate = entitlement.expirationDate
            status.isTrialing = entitlement.periodType == .trial
        }
        
        subscriptionStatusSubject.send(status)
        
        // Log subscription status update
        if status.isSubscribed {
            print("[SubscriptionService] Subscription status updated: Active (\(status.subscriptionTier.rawValue))")
        } else {
            print("[SubscriptionService] Subscription status updated: Not subscribed")
        }
    }
    
    private func listenForCustomerInfoUpdates() async {
        for await customerInfo in Purchases.shared.customerInfoStream {
            await updateStatusFromCustomerInfo(customerInfo)
        }
    }
    
    deinit {
        customerInfoListenerTask?.cancel()
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

