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
    @State private var authMode: AuthMode = .signIn
    @State private var showingMagicLinkSent = false
    
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
                        authForm
                        socialAuthSection
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
            .alert("Magic Link Sent", isPresented: $showingMagicLinkSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your email for a sign-in link. Click the link to complete sign-in.")
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
            .onChange(of: viewModel.showingMagicLinkSent) { _, newValue in
                if newValue {
                    showingMagicLinkSent = true
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
    
    private var authForm: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Mode toggle
            Picker("Auth Mode", selection: $authMode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Sign Up").tag(AuthMode.signUp)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // Email field
            CTTextField(
                placeholder: "Email",
                text: $viewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress
            )
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // Password field (only for sign in/sign up, not magic link)
            if authMode != .magicLink {
                CTSecureTextField(
                    placeholder: "Password",
                    text: $viewModel.password
                )
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            
            // Primary action button
            CTButton(
                authMode.buttonTitle,
                style: .primary,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await performAuthAction()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // Magic link toggle
            if authMode != .magicLink {
                Button {
                    withAnimation {
                        authMode = .magicLink
                    }
                } label: {
                    Text("Use magic link instead")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.primary)
                }
            } else {
                Button {
                    withAnimation {
                        authMode = .signIn
                    }
                } label: {
                    Text("Use password instead")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
    }
    
    private var socialAuthSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Divider
            HStack {
                Rectangle()
                    .fill(DesignTokens.Colors.textSecondary.opacity(0.3))
                    .frame(height: 1)
                Text("OR")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                Rectangle()
                    .fill(DesignTokens.Colors.textSecondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // Apple Sign-In
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
            
            // Google Sign-In
            CTButton(
                "Continue with Google",
                style: .secondary,
                isLoading: false
            ) {
                Task {
                    await viewModel.signInWithGoogle()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .disabled(viewModel.isLoading)
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
    
    // MARK: - Actions
    
    private func performAuthAction() async {
        switch authMode {
        case .signIn:
            await viewModel.signIn()
        case .signUp:
            await viewModel.signUp()
        case .magicLink:
            await viewModel.sendMagicLink()
        }
    }
    
}

// MARK: - Auth Mode

enum AuthMode {
    case signIn
    case signUp
    case magicLink
    
    var buttonTitle: String {
        switch self {
        case .signIn:
            return "Sign In"
        case .signUp:
            return "Sign Up"
        case .magicLink:
            return "Send Magic Link"
        }
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
    AuthLandingView(authManager: SupabaseMockAuthController())
}
