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
            
            let response: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
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
            
            var updatedProfile = profile
            updatedProfile.userId = userId
            updatedProfile.updatedAt = Date()
            
            let response: [UserProfile] = try await client
                .from("user_profiles")
                .upsert(updatedProfile)
                .select()
                .execute()
                .value
            
            guard let savedProfile = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            _cachedProfile = savedProfile
            return savedProfile
        } catch {
            Self.logger.error("Failed to upsert user profile: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func deleteProfile() async throws {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            try await client
                .from("user_profiles")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            _cachedProfile = nil
        } catch {
            Self.logger.error("Failed to delete user profile: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
}
