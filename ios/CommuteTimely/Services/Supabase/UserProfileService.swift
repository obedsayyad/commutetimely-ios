//
// UserProfileService.swift
// CommuteTimely
//
// Supabase user_profiles table service
//

import Foundation
import Supabase
import OSLog

@MainActor
final class UserProfileService: UserProfileServiceProtocol {
    private let client: SupabaseClient
    private var _cachedProfile: UserProfile?
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "UserProfileService")
    
    var cachedProfile: UserProfile? {
        _cachedProfile
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func fetchCurrentUserProfile() async throws -> UserProfile {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            // In Supabase, user_profiles typically uses 'id' as the primary key
            // matching the auth user's id, not a separate 'user_id' column
            let response: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            
            guard let profile = response.first else {
                throw SupabaseError.notFound
            }
            
            _cachedProfile = profile
            return profile
        } catch {
            Self.logger.error("Failed to fetch user profile: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func upsertProfile(_ profile: UserProfile) async throws -> UserProfile {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            // Create a struct with only the fields that exist in the database
            // The table uses 'id' as the primary key (matching auth user id)
            // Note: 'name' column was removed - database only has id, email, avatar_url
            struct UserProfileUpsertRequest: Codable {
                let id: UUID
                let email: String?
                let avatarURL: URL?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case email
                    case avatarURL = "avatar_url"
                }
            }
            
            let upsertRequest = UserProfileUpsertRequest(
                id: userId,  // Use auth user id as the profile id
                email: profile.email,
                avatarURL: profile.avatarURL
            )
            
            // Perform upsert without select to avoid decoding issues
            try await client
                .from("user_profiles")
                .upsert(upsertRequest)
                .execute()
            
            // Return updated profile directly (avoids potential decoding issues with missing columns)
            let savedProfile = UserProfile(
                id: userId,
                userId: userId,
                name: profile.name,
                email: profile.email,
                avatarURL: profile.avatarURL
            )
            
            _cachedProfile = savedProfile
            return savedProfile
        } catch {
            Self.logger.error("Failed to upsert user profile: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func deleteProfile() async throws {
        do {
            let user = try await client.auth.user()
            let userId = user.id
            
            try await client
                .from("user_profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()
            
            _cachedProfile = nil
        } catch {
            Self.logger.error("Failed to delete user profile: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
}
