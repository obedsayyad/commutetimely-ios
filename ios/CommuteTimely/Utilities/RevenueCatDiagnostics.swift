//
// RevenueCatDiagnostics.swift
// CommuteTimely
//
// Diagnostic helper for debugging RevenueCat configuration
//

import Foundation
import RevenueCat

#if DEBUG
struct RevenueCatDiagnostics {
    
    /// Run comprehensive diagnostics and print results to console
    static func runDiagnostics() async {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 REVENUECAT DIAGNOSTICS")
        print(String(repeating: "=", count: 60) + "\n")
        
        // 1. Check API Key
        await checkAPIKey()
        
        // 2. Check Offerings
        await checkOfferings()
        
        // 3. Check Customer Info
        await checkCustomerInfo()
        
        // 4. Check Configuration
        checkConfiguration()
        
        print("\n" + String(repeating: "=", count: 60))
        print("✅ DIAGNOSTICS COMPLETE")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Diagnostic Checks
    
    private static func checkAPIKey() async {
        print("📋 1. API Key Check")
        print(String(repeating: "-", count: 60))
        
        let apiKey = AppSecrets.revenueCatPublicAPIKey
        
        // Check format
        if apiKey.hasPrefix("appl_") {
            print("✅ API key format is correct (starts with 'appl_')")
        } else if apiKey.hasPrefix("goog_") {
            print("❌ ERROR: Using Android API key (starts with 'goog_')")
            print("   Action: Get iOS API key from RevenueCat Dashboard")
        } else if apiKey.hasPrefix("sk_") {
            print("❌ ERROR: Using SECRET key (starts with 'sk_')")
            print("   Action: Use PUBLIC key instead")
        } else {
            print("⚠️  WARNING: API key format is unusual")
            print("   Expected: Starts with 'appl_' for iOS")
        }
        
        // Check length
        if apiKey.count > 20 {
            print("✅ API key length looks valid (\(apiKey.count) characters)")
        } else {
            print("⚠️  WARNING: API key seems too short (\(apiKey.count) characters)")
        }
        
        print("   Current key: \(apiKey.prefix(15))...\n")
    }
    
    private static func checkOfferings() async {
        print("📦 2. Offerings Check")
        print(String(repeating: "-", count: 60))
        
        do {
            let offerings = try await Purchases.shared.offerings()
            
            if offerings.all.isEmpty {
                print("❌ ERROR: No offerings found")
                print("   Action: Create an offering in RevenueCat Dashboard")
            } else {
                print("✅ Found \(offerings.all.count) offering(s)")
                
                for (key, offering) in offerings.all {
                    print("\n   Offering: \(key)")
                    print("   - Identifier: \(offering.identifier)")
                    print("   - Packages: \(offering.availablePackages.count)")
                    
                    if offering.identifier == offerings.current?.identifier {
                        print("   - Status: CURRENT ✅")
                    } else {
                        print("   - Status: Not current")
                    }
                }
            }
            
            if let current = offerings.current {
                print("\n✅ Current offering is set: \(current.identifier)")
                
                if current.availablePackages.isEmpty {
                    print("❌ ERROR: Current offering has no packages")
                    print("   Action: Add packages to the offering in RevenueCat Dashboard")
                } else {
                    print("✅ Current offering has \(current.availablePackages.count) package(s)")
                    
                    for package in current.availablePackages {
                        print("\n   Package: \(package.identifier)")
                        print("   - Product ID: \(package.storeProduct.productIdentifier)")
                        print("   - Price: \(package.storeProduct.localizedPriceString)")
                        
                        // Verify product ID matches expected
                        let expectedIDs = [
                            "com.develentcorp.commutetimely.pro.monthly",
                            "com.develentcorp.commutetimely.pro.yearly"
                        ]
                        
                        if expectedIDs.contains(package.storeProduct.productIdentifier) {
                            print("   - Match: ✅ Product ID matches StoreKit config")
                        } else {
                            print("   - Match: ⚠️  Product ID doesn't match expected IDs")
                            print("     Expected: \(expectedIDs.joined(separator: ", "))")
                        }
                    }
                }
            } else {
                print("\n❌ ERROR: No current offering is set")
                print("   Action: Mark an offering as 'Current' in RevenueCat Dashboard")
            }
            
        } catch {
            print("❌ ERROR: Failed to fetch offerings")
            print("   Error: \(error.localizedDescription)")
            
            if let rcError = error as? ErrorCode {
                print("   RevenueCat Error Code: \(rcError.errorCode)")
                
                switch rcError {
                case .configurationError:
                    print("\n   💡 Configuration Error - Check:")
                    print("      • API key is correct")
                    print("      • Offerings exist in RevenueCat Dashboard")
                    print("      • Products are linked to offerings")
                case .networkError:
                    print("\n   💡 Network Error - Check internet connection")
                default:
                    print("\n   💡 Error type: \(rcError)")
                }
            }
        }
        
        print("")
    }
    
    private static func checkCustomerInfo() async {
        print("👤 3. Customer Info Check")
        print(String(repeating: "-", count: 60))
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            
            print("✅ Customer info retrieved successfully")
            print("   - User ID: \(customerInfo.originalAppUserId)")
            print("   - Active entitlements: \(customerInfo.entitlements.active.count)")
            
            if customerInfo.entitlements.active.isEmpty {
                print("   - Status: No active subscriptions")
            } else {
                print("\n   Active Entitlements:")
                for (key, entitlement) in customerInfo.entitlements.active {
                    print("   - \(key)")
                    print("     • Product: \(entitlement.productIdentifier)")
                    print("     • Expires: \(entitlement.expirationDate?.description ?? "Never")")
                }
            }
            
            // Check for expected entitlement
            let expectedEntitlement = "CommuteTimely Pro"
            if customerInfo.entitlements[expectedEntitlement] != nil {
                print("\n✅ Expected entitlement '\(expectedEntitlement)' exists")
                
                if customerInfo.entitlements[expectedEntitlement]?.isActive == true {
                    print("   Status: ACTIVE ✅")
                } else {
                    print("   Status: Inactive")
                }
            } else {
                print("\n⚠️  Expected entitlement '\(expectedEntitlement)' not found")
                print("   Note: This is normal if user hasn't purchased yet")
            }
            
        } catch {
            print("⚠️  Could not retrieve customer info")
            print("   Error: \(error.localizedDescription)")
            print("   Note: This is normal if user hasn't purchased yet")
        }
        
        print("")
    }
    
    private static func checkConfiguration() {
        print("⚙️  4. Configuration Check")
        print(String(repeating: "-", count: 60))
        
        // Check Supabase configuration
        if AppSecrets.isSupabaseKeyValid {
            print("✅ Supabase key format is valid")
        } else {
            print("⚠️  Supabase key format may be invalid")
        }
        
        // Check expected product IDs
        let expectedProducts = [
            "com.develentcorp.commutetimely.pro.monthly",
            "com.develentcorp.commutetimely.pro.yearly"
        ]
        
        print("\n   Expected Product IDs:")
        for productId in expectedProducts {
            print("   - \(productId)")
        }
        
        // Check entitlement identifier
        let expectedEntitlement = "CommuteTimely Pro"
        print("\n   Expected Entitlement: '\(expectedEntitlement)'")
        print("   Note: This MUST match exactly in RevenueCat Dashboard")
        
        print("")
    }
    
    // MARK: - Quick Checks
    
    /// Quick check if RevenueCat is properly configured
    static func isConfigured() async -> Bool {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.current != nil && !offerings.current!.availablePackages.isEmpty
        } catch {
            return false
        }
    }
    
    /// Print a summary status
    static func printStatus() async {
        let isConfigured = await isConfigured()
        
        if isConfigured {
            print("✅ RevenueCat is properly configured")
        } else {
            print("❌ RevenueCat configuration incomplete")
            print("   Run RevenueCatDiagnostics.runDiagnostics() for details")
        }
    }
}
#endif
