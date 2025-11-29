//
// AuthLandingView.swift
// CommuteTimely
//
// Clerk-powered authentication landing screen
//

import SwiftUI
import Foundation
import Combine
#if canImport(Clerk)
import Clerk
#endif

struct AuthLandingView: View {
    @ObservedObject var authManager: AuthSessionController
    @Environment(\.dismiss) private var dismiss
    #if canImport(Clerk)
    @Environment(\.clerk) private var clerk
    #endif
    @State private var showingClerkAuth = false
    @State private var showingPrivacyNotice = false
    @State private var isPreparingClerk = false
    @State private var clerkErrorMessage: String?
    @State private var showingClerkError = false
    
    private var isMockAuth: Bool {
        authManager is ClerkMockProvider
    }
    
    private var supportsClerkUI: Bool {
        #if canImport(Clerk)
        if #available(iOS 17.0, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        header
                        benefits
                        signInSection
                        privacyButton
                        skipButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            #if canImport(Clerk)
            .fullScreenCover(isPresented: $showingClerkAuth) {
                ClerkAuthFullScreen {
                    showingClerkAuth = false
                }
            }
            #endif
            .sheet(isPresented: $showingPrivacyNotice) {
                AuthPrivacyNoticeView()
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
            .alert("Unable to reach Clerk", isPresented: $showingClerkError) {
                Button("Retry") {
                    Task {
                        await prepareClerkIfNeeded()
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(clerkErrorMessage ?? "Please check your network connection and try again.")
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Colors.primary)
                .padding(.top, DesignTokens.Spacing.xl)
            
            Text("Back up your trips")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Sign in with Clerk to sync across devices. Your commute data stays private and local.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(.top, DesignTokens.Spacing.xxl)
    }
    
    private var benefits: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BenefitRow(icon: "icloud.fill", text: "Automatic backup to iCloud")
            BenefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync trips across all your devices")
            BenefitRow(icon: "brain.head.profile", text: "Personalized commute predictions")
            BenefitRow(icon: "lock.fill", text: "Clerk manages secure sign-in and tokens")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
    
    private var signInSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            CTButton(
                isPreparingClerk ? "Preparing Clerk…" : "Sign in with Clerk",
                style: .primary,
                isLoading: isPreparingClerk
            ) {
                presentClerkFlow()
            }
            .accessibilityIdentifier("clerk-sign-in")
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            if isMockAuth, let mockProvider = authManager as? ClerkMockProvider {
                Button("Complete mock sign-in") {
                    mockProvider.completeMockSignIn()
                }
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Colors.primary)
                .accessibilityIdentifier("mock-sign-in")
            }
        }
    }
    
    private var privacyButton: some View {
        Button {
            showingPrivacyNotice = true
        } label: {
            Text("Privacy & data usage")
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(DesignTokens.Colors.primary)
                .underline()
        }
        .padding(.bottom, DesignTokens.Spacing.lg)
    }
    
    private var skipButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Maybe later")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    private func presentClerkFlow() {
        guard !isPreparingClerk else { return }

        if isMockAuth {
            #if canImport(Clerk)
            if supportsClerkUI {
                showingClerkAuth = true
            }
            #endif
            return
        }

        guard supportsClerkUI else {
            clerkErrorMessage = "Sign-in with Clerk requires iOS 17 or later on this device. You can keep using CommuteTimely without signing in."
            showingClerkError = true
            return
        }
        
        Task {
            await prepareClerkIfNeeded()
        }
    }

    #if canImport(Clerk)
    @MainActor
    private func prepareClerkIfNeeded() async {
        isPreparingClerk = true
        clerkErrorMessage = nil
        defer { isPreparingClerk = false }

        do {
            if !clerk.isLoaded {
                try await clerk.load()
            }

            if let clerkAuth = authManager as? ClerkAuthController {
                clerkAuth.reloadCachedSession()
            }

            showingClerkAuth = true
        } catch {
            clerkErrorMessage = formatErrorMessage(error)
            showingClerkError = true
        }
    }
    #else
    @MainActor
    private func prepareClerkIfNeeded() async {
        clerkErrorMessage = "Clerk sign-in is not available on this OS version."
        showingClerkError = true
    }
    #endif
    
    private func formatErrorMessage(_ error: Error) -> String {
        let errorDescription = error.localizedDescription
        
        // Check for NSURLErrorDomain errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please check your network settings and try again."
            case .timedOut:
                return "Connection timed out. Please check your internet connection and try again."
            case .cannotFindHost, .cannotConnectToHost:
                return "Unable to connect to Clerk. Please check your internet connection and try again."
            case .dnsLookupFailed:
                return "Network error. Please check your internet connection and try again."
            default:
                return "Network error. Please check your internet connection and try again."
            }
        }
        
        // Filter out technical error codes from the message
        if errorDescription.contains("NSURLErrorDomain") {
            if errorDescription.contains("-1000") {
                return "Unable to connect to Clerk. Please check your internet connection and try again."
            }
            if errorDescription.contains("-1001") {
                return "Connection timed out. Please check your internet connection and try again."
            }
            if errorDescription.contains("-1009") {
                return "No internet connection. Please check your network settings and try again."
            }
            // Generic network error message
            return "Network error. Please check your internet connection and try again."
        }
        
        // For other errors, return a user-friendly message
        // Remove technical error codes if present
        var message = errorDescription
        
        // Remove patterns like "(NSURLErrorDomain error -1000.)"
        let patterns = [
            "\\(NSURLErrorDomain error -?\\d+\\.?\\)",
            "\\(.*error.*-?\\d+.*\\)",
            "NSURLErrorDomain",
            "error -\\d+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(message.startIndex..., in: message)
                message = regex.stringByReplacingMatches(in: message, options: [], range: range, withTemplate: "")
            }
        }
        
        message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If message is empty or too technical, provide a default
        if message.isEmpty || message.contains("NSURLErrorDomain") || message.contains("error -") {
            return "Unable to connect to Clerk. Please check your internet connection and try again."
        }
        
        return message
    }

}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.primary)
                .frame(width: 28)
            
            Text(text)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    AuthLandingView(authManager: ClerkMockProvider())
}


#if canImport(Clerk)
// MARK: - Clerk Auth Full Screen

private struct ClerkAuthFullScreen: View {
    @Environment(\.dismiss) private var dismiss
    let onClose: () -> Void

    var body: some View {
        NavigationView {
            AuthView()
                .accessibilityLabel("Clerk Sign In")
                .navigationTitle("Sign in")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            onClose()
                            dismiss()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea()
    }
}
#endif
