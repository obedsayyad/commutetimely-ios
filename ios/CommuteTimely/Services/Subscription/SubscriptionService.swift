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
    func getCurrentOfferings() async throws -> Offerings?
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
    
    func getCurrentOfferings() async throws -> Offerings? {
        print("[SubscriptionService] 🔄 Fetching offerings from RevenueCat...")
        
        do {
            let offerings = try await Purchases.shared.offerings()
            
            print("[SubscriptionService] ✅ Successfully loaded offerings")
            print("[SubscriptionService] 📊 Offerings Summary:")
            print("[SubscriptionService]   - Total offerings: \(offerings.all.count)")
            print("[SubscriptionService]   - Current offering: \(offerings.current?.identifier ?? "NONE")")
            
            if let current = offerings.current {
                print("[SubscriptionService] 📦 Current Offering Details:")
                print("[SubscriptionService]   - ID: \(current.identifier)")
                print("[SubscriptionService]   - Description: \(current.serverDescription)")
                print("[SubscriptionService]   - Available packages: \(current.availablePackages.count)")
                
                for (index, package) in current.availablePackages.enumerated() {
                    print("[SubscriptionService]   Package \(index + 1):")
                    print("[SubscriptionService]     - Identifier: \(package.identifier)")
                    print("[SubscriptionService]     - Product ID: \(package.storeProduct.productIdentifier)")
                    print("[SubscriptionService]     - Title: \(package.storeProduct.localizedTitle)")
                    print("[SubscriptionService]     - Price: \(package.storeProduct.localizedPriceString)")
                    print("[SubscriptionService]     - Subscription Period: \(package.storeProduct.subscriptionPeriod?.debugDescription ?? "N/A")")
                }
            } else {
                print("[SubscriptionService] ⚠️ WARNING: No current offering is set!")
                print("[SubscriptionService] 💡 Action Required:")
                print("[SubscriptionService]    1. Go to RevenueCat Dashboard")
                print("[SubscriptionService]    2. Navigate to Offerings")
                print("[SubscriptionService]    3. Create an offering and mark it as 'Current'")
            }
            
            // List all offerings for debugging
            if !offerings.all.isEmpty {
                print("[SubscriptionService] 📋 All Available Offerings:")
                for (key, offering) in offerings.all {
                    print("[SubscriptionService]   - \(key): \(offering.identifier) (Packages: \(offering.availablePackages.count))")
                }
            }
            
            return offerings
        } catch {
            print("[SubscriptionService] ❌ Failed to load offerings")
            
            if let rcError = error as? ErrorCode {
                print("[SubscriptionService] 🔴 RevenueCat Error Details:")
                print("[SubscriptionService]   - Error Code: \(rcError.errorCode)")
                print("[SubscriptionService]   - Error Type: \(rcError)")
                print("[SubscriptionService]   - Description: \(rcError.localizedDescription)")
                
                switch rcError {
                case .configurationError:
                    print("[SubscriptionService] 💡 Configuration Error - Possible causes:")
                    print("[SubscriptionService]    • Invalid API key")
                    print("[SubscriptionService]    • API key is for wrong project")
                    print("[SubscriptionService]    • No offerings configured in RevenueCat Dashboard")
                    print("[SubscriptionService]    • Products not properly linked to offerings")
                case .networkError:
                    print("[SubscriptionService] 💡 Network Error - Check internet connection")
                case .storeProblemError:
                    print("[SubscriptionService] 💡 Store Problem - App Store Connect issue")
                case .productNotAvailableForPurchaseError:
                    print("[SubscriptionService] 💡 Products not available - Check App Store Connect")
                default:
                    print("[SubscriptionService] 💡 Unexpected error type")
                }
            } else {
                print("[SubscriptionService] 🔴 Non-RevenueCat Error:")
                print("[SubscriptionService]   - \(error.localizedDescription)")
            }
            
            throw error
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
    
    func getCurrentOfferings() async throws -> Offerings? {
        return nil
    }
}
