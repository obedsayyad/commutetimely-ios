//
// WelcomeView.swift
// CommuteTimely
//
// Welcome screen with app value proposition
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    DesignTokens.Colors.primaryFallback(),
                    DesignTokens.Colors.secondaryFallback()
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()
                
                // App Icon/Logo
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.0 : 0.5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.primaryFallback())
                }
                .padding(.bottom, DesignTokens.Spacing.lg)
                
                // Title
                Text("CommuteTimely")
                    .font(DesignTokens.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Subtitle
                Text("Never miss your arrival time")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                
                Spacer()
                
                // Features
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    FeatureRow(
                        icon: "mappin.and.ellipse",
                        title: "Smart Predictions",
                        description: "AI analyzes traffic and weather in real-time"
                    )
                    
                    FeatureRow(
                        icon: "bell.badge.fill",
                        title: "Timely Alerts",
                        description: "Get notified exactly when you should leave"
                    )
                    
                    FeatureRow(
                        icon: "arrow.triangle.branch",
                        title: "Route Options",
                        description: "See alternatives if conditions change"
                    )
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                
                Spacer()
                
                // Continue Button
                Button(action: onContinue) {
                    HStack {
                        Text("Get Started")
                            .font(DesignTokens.Typography.headline)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignTokens.Size.buttonHeight)
                    .background(Color.white)
                    .cornerRadius(DesignTokens.CornerRadius.md)
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
        }
        .onAppear {
            let animation = UIAccessibility.isReduceMotionEnabled 
                ? DesignTokens.Animation.quick 
                : DesignTokens.Animation.bouncy.repeatForever(autoreverses: true)
            withAnimation(animation) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}

