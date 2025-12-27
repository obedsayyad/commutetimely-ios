//
// AuthPrivacyNoticeView.swift
// CommuteTimely
//
// Privacy notice for authentication
//

import SwiftUI

struct AuthPrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Text("Your Privacy Matters")
                        .font(DesignTokens.Typography.title1)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .padding(.top, DesignTokens.Spacing.lg)
                    
                    PrivacySection(
                        icon: "lock.shield.fill",
                        title: "What we store",
                        description: "We store an encrypted user ID to sync your trips. Location data stays on your device unless you opt in to sharing."
                    )
                    
                    PrivacySection(
                        icon: "icloud.fill",
                        title: "Cloud backup",
                        description: "Your trip names, times, and preferences are backed up to our secure servers. We never share this data with third parties."
                    )
                    
                    PrivacySection(
                        icon: "hand.raised.fill",
                        title: "You're in control",
                        description: "You can delete your data anytime from Settings. Signing out removes all synced data from your device."
                    )
                    
                    PrivacySection(
                        icon: "eye.slash.fill",
                        title: "What we don't collect",
                        description: "We don't track your real-time location, sell your data, or show ads. Your commute is your business."
                    )
                    
                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.md)
                    
                    Text("By signing in, you agree to our Terms of Service and Privacy Policy.")
                        .font(DesignTokens.Typography.footnote)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacySection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DesignTokens.Colors.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(description)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    AuthPrivacyNoticeView()
}

