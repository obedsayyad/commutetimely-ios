//
// UserProfileView.swift
// CommuteTimely
//
// User profile management view using Supabase
//

import SwiftUI

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = DIContainer.shared.authManager
    private let userProfileService = DIContainer.shared.userProfileService
    
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let profile = profile {
                    profileContent(profile: profile)
                } else {
                    noProfileView
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                        .disabled(isSaving)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                if !isEditing && profile != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Edit") {
                            isEditing = true
                            editedName = profile?.name ?? ""
                        }
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading profile...")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func profileContent(profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // User header section
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Avatar
                    Group {
                        if let avatarURL = profile.avatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    
                    // Name (editable if editing)
                    if isEditing {
                        CTTextField(
                            placeholder: "Full name",
                            text: $editedName,
                            icon: "person.fill"
                        )
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                    } else {
                        VStack(spacing: DesignTokens.Spacing.xs) {
                            if let name = profile.name, !name.isEmpty {
                                Text(name)
                                    .font(DesignTokens.Typography.title2)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                            } else if let user = authManager.currentUser, let displayName = user.displayName {
                                Text(displayName)
                                    .font(DesignTokens.Typography.title2)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                            } else {
                                Text("User")
                                    .font(DesignTokens.Typography.title2)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                            }
                            
                            if let email = profile.email ?? authManager.currentUser?.email {
                                Text(email)
                                    .font(DesignTokens.Typography.body)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.lg)
                
                Divider()
                    .padding(.horizontal, DesignTokens.Spacing.md)
                
                // User ID section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("User ID")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(profile.userId.uuidString)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
    }
    
    private var noProfileView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            Text("No profile found")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Your profile will be created automatically when you sign in.")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(.top, DesignTokens.Spacing.xl)
    }
    
    // MARK: - Actions
    
    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            profile = try await userProfileService.fetchCurrentUserProfile()
        } catch {
            // Profile might not exist yet - that's okay
            // Use auth manager's current user as fallback
            if let user = authManager.currentUser {
                profile = UserProfile(
                    id: UUID(),
                    userId: UUID(uuidString: user.id) ?? UUID(),
                    name: user.displayName,
                    email: user.email,
                    avatarURL: user.imageURL,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    private func saveProfile() async {
        guard var profile = profile else { return }
        
        isSaving = true
        errorMessage = nil
        
        // Update profile with edited name
        profile.name = editedName.isEmpty ? nil : editedName
        
        do {
            profile = try await userProfileService.upsertProfile(profile)
            self.profile = profile
            isEditing = false
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            showingError = true
        }
        
        isSaving = false
    }
}

#Preview {
    UserProfileView()
}
