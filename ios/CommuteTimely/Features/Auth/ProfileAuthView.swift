//
// ProfileAuthView.swift
// CommuteTimely
//
// Profile view showing connected auth providers in Settings
//

import SwiftUI

struct ProfileAuthView: View {
    @ObservedObject var authManager: AuthSessionController
    @State private var showingSignOut = false
    @State private var showingUserProfile = false
    @State private var avatarUrl: String = ""
    
    var body: some View {
        Group {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                VStack(spacing: DesignTokens.Spacing.md) {
                    userHeader(for: user)
                    
                    CTButton("Manage account", style: .secondary) {
                        showingUserProfile = true
                    }
                    
                    Button(role: .destructive) {
                        showingSignOut = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                }
                .alert("Sign Out?", isPresented: $showingSignOut) {
                    Button("Cancel", role: .cancel) {}
                    Button("Sign Out", role: .destructive) {
                        Task {
                            // Sign out from Supabase
                            _ = try? await authManager.signOut()
                        }
                    }
                } message: {
                    Text("Your trips will remain on this device, but won't sync until you sign in again.")
                }
                .sheet(isPresented: $showingUserProfile) {
                    AccountView()
                }
                .task {
                    await loadAvatar()
                }
                .onChange(of: showingUserProfile) { _, isShowing in
                    if !isShowing {
                        // Refresh avatar when returning from account page
                        Task { await loadAvatar() }
                    }
                }
            } else {
                notSignedInView
            }
        }
    }
    
    private func loadAvatar() async {
        do {
            let profile = try await SupabaseService.shared.fetchUserProfile()
            avatarUrl = profile.avatarUrl ?? ""
        } catch {
            // Ignore errors - just use placeholder
        }
    }
    
    private func userHeader(for user: AuthenticatedUser) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // User avatar from Supabase
            profileImage
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                if let displayName = user.displayName {
                    Text(displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                
                if let email = user.email {
                    Text(email)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var profileImage: some View {
        if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    placeholderImage
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var placeholderImage: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundColor(DesignTokens.Colors.textSecondary)
    }
    
    private var notSignedInView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            Text("Not signed in")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Sign in to back up trips and sync across devices")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}

#Preview {
    let mock = SupabaseMockAuthController()
    mock.completeMockSignIn()
    return ProfileAuthView(authManager: mock)
}
