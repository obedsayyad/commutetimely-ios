//
// PremiumFeatureGate.swift
// CommuteTimely
//
// Reusable utility for gating premium features
//

import SwiftUI
import Combine

// MARK: - View Modifier

struct PremiumFeatureGate: ViewModifier {
    let featureName: String
    let subscriptionService: SubscriptionServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    
    @State private var hasAccess = false
    @State private var isCheckingAccess = true
    @State private var showingPaywall = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: hasAccess ? 0 : 3)
                .disabled(!hasAccess)
            
            if !hasAccess && !isCheckingAccess {
                premiumOverlay
            }
        }
        .task {
            await checkAccess()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(analyticsService: analyticsService)
        }
    }
    
    private var premiumOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundColor(DesignTokens.Colors.primaryFallback())
            
            Text("Premium Feature")
                .font(DesignTokens.Typography.headline)
            
            Text(featureName)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                analyticsService.trackEvent(.subscriptionStarted(tier: "feature_gate_\(featureName)"))
                showingPaywall = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Pro")
                }
                .font(DesignTokens.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.primaryFallback())
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground).opacity(0.95))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(radius: 10)
    }
    
    private func checkAccess() async {
        isCheckingAccess = true
        hasAccess = await subscriptionService.checkEntitlement("CommuteTimely Pro")
        isCheckingAccess = false
    }
}

// MARK: - View Extension

extension View {
    /// Premium feature gate with explicit service parameters
    func premiumFeatureGate(
        _ featureName: String,
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) -> some View {
        modifier(PremiumFeatureGate(
            featureName: featureName,
            subscriptionService: subscriptionService,
            analyticsService: analyticsService
        ))
    }
    
    /// Convenience method that uses DIContainer defaults
    /// Must be called from @MainActor context
    @MainActor
    func premiumFeatureGate(_ featureName: String) -> some View {
        modifier(PremiumFeatureGate(
            featureName: featureName,
            subscriptionService: DIContainer.shared.subscriptionService,
            analyticsService: DIContainer.shared.analyticsService
        ))
    }
}

// MARK: - Premium Badge

struct PremiumBadge: View {
    var size: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.7))
            Text("PRO")
                .font(.system(size: size * 0.6, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, size * 0.5)
        .padding(.vertical, size * 0.3)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(size * 0.4)
    }
}

// MARK: - Inline Premium Gate

struct InlinePremiumGate: View {
    let featureName: String
    let onUpgrade: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text(featureName)
                        .font(DesignTokens.Typography.subheadline)
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text("Premium feature")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            Button {
                onUpgrade()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("Upgrade")
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignTokens.Colors.primaryFallback())
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

// MARK: - Feature Access Checker

@MainActor
class PremiumFeatureChecker: ObservableObject {
    @Published var hasProAccess = false
    @Published var isChecking = true
    
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
    }
    
    @MainActor
    func setup() {
        // Subscribe to subscription status changes
        subscriptionService.subscriptionStatus
            .map { $0.isSubscribed }
            .assign(to: &$hasProAccess)
        
        Task {
            await checkAccess()
        }
    }
    
    @MainActor
    static func create() -> PremiumFeatureChecker {
        let checker = PremiumFeatureChecker(subscriptionService: DIContainer.shared.subscriptionService)
        checker.setup()
        return checker
    }
    
    func checkAccess() async {
        isChecking = true
        hasProAccess = await subscriptionService.checkEntitlement("CommuteTimely Pro")
        isChecking = false
    }
}

