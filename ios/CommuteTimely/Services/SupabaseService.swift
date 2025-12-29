//
// SupabaseService.swift
// CommuteTimely
//
// Centralized Supabase service layer
//

import Foundation
import Supabase

@MainActor
final class SupabaseService {

    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: AppSecrets.supabaseURL)!,
            supabaseKey: AppSecrets.supabaseAnonKey
        )
    }

    func saveUserProfile(fullName: String, firstName: String, avatarUrl: String? = nil) async throws {
        let user = try await client.auth.session.user

        var profileData: [String: String] = [
            "id": user.id.uuidString,
            "full_name": fullName,
            "first_name": firstName,
            "email": user.email ?? "",
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Only include avatar_url if provided
        if let avatarUrl = avatarUrl {
            profileData["avatar_url"] = avatarUrl
        }

        try await client
            .from("user_profiles")
            .upsert(profileData, onConflict: "id")
            .execute()
    }
    
    func fetchUserProfile() async throws -> (fullName: String?, firstName: String?, email: String?, avatarUrl: String?) {
        let user = try await client.auth.session.user
        
        struct ProfileResponse: Decodable {
            let full_name: String?
            let first_name: String?
            let email: String?
            let avatar_url: String?
        }
        
        let response: [ProfileResponse] = try await client
            .from("user_profiles")
            .select("full_name, first_name, email, avatar_url")
            .eq("id", value: user.id.uuidString)
            .execute()
            .value
        
        let profile = response.first
        return (fullName: profile?.full_name, firstName: profile?.first_name, email: profile?.email, avatarUrl: profile?.avatar_url)
    }
    
    // MARK: - Avatar Upload
    
    func uploadAvatar(imageData: Data) async throws -> String {
        // Verify user is authenticated first
        let session = try await client.auth.session
        let user = session.user
        
        // Use exact path format: {user_id}/avatar.png
        let filePath = "\(user.id.uuidString)/avatar.png"
        
        // Upload to Supabase Storage (bucket: "avatars")
        _ = try await client.storage
            .from("avatars")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/png",
                    upsert: true
                )
            )
        
        // Get public URL
        let publicUrl = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return publicUrl.absoluteString
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        let session = try await client.auth.session
        
        // Call Edge Function to delete everything (auth user, profile, storage)
        // The Edge Function uses service role to delete the auth user
        do {
            _ = try await client.functions.invoke(
                "delete-user",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )
        } catch {
            // If Edge Function fails, try to at least delete profile and sign out
            _ = try? await client
                .from("user_profiles")
                .delete()
                .eq("id", value: session.user.id.uuidString)
                .execute()
            
            try await client.auth.signOut()
            throw error
        }
        
        // Sign out locally after successful deletion
        try await client.auth.signOut()
    }
}
