//
// AuthLandingView.swift
// CommuteTimely
//
// Supabase-powered authentication landing screen
//

import SwiftUI
import Foundation
import Combine
import AuthenticationServices

struct AuthLandingView: View {
    @ObservedObject var authManager: AuthSessionController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthViewModel
    
    @State private var showingPrivacyNotice = false
    
    init(authManager: AuthSessionController) {
        self.authManager = authManager
        _viewModel = StateObject(wrappedValue: AuthViewModel(
            authService: DIContainer.shared.supabaseAuthService,
            authManager: authManager
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        header
                        appleSignInButton
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
            .sheet(isPresented: $showingPrivacyNotice) {
                AuthPrivacyNoticeView()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                if newValue {
                    dismiss()
                }
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
            
            Text("Sign in to sync across devices. Your commute data stays private and secure.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(.top, DesignTokens.Spacing.xxl)
    }
    
    private var appleSignInButton: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
                // Generate nonce for this request
                let nonce = viewModel.generateNonce()
                request.nonce = viewModel.sha256(nonce)
                // Store nonce for later use
                viewModel.setStoredNonce(nonce)
            },
            onCompletion: { result in
                Task {
                    if let nonce = viewModel.getStoredNonce() {
                        await viewModel.handleAppleAuthorizationResult(result, nonce: nonce)
                    } else {
                        viewModel.errorMessage = "Sign-in failed: missing nonce"
                    }
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: DesignTokens.Size.buttonHeight)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .disabled(viewModel.isLoading)
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
}

// MARK: - Preview

#Preview {
    AuthLandingView(authManager: SupabaseMockAuthController())
}
