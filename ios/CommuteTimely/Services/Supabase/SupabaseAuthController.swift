//
// SupabaseAuthController.swift
// CommuteTimely
//
// Supabase-backed AuthSessionController implementation
//

import Foundation
import Combine
import Supabase
import OSLog

@MainActor
final class SupabaseAuthController: AuthSessionController {
    private let authService: SupabaseAuthServiceProtocol
    private var authStateTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.commutetimely.auth", category: "SupabaseAuthController")
    
    init(authService: SupabaseAuthServiceProtocol) {
        self.authService = authService
        super.init()
        Self.logger.info("SupabaseAuthController initialized")
        observeAuthState()
    }
    
    func cleanup() {
        authStateTask?.cancel()
        authStateTask = nil
    }
    
    override func idToken(template: String? = nil) async throws -> String? {
        guard let authService = authService as? SupabaseAuthService else {
            Self.logger.warning("Auth service is not SupabaseAuthService")
            return nil
        }
        
        let session = await authService.getCurrentSession()
        return session?.accessToken
    }
    
    override func signOut() async throws {
        do {
            try await authService.signOut()
            updateUser(nil)
            Self.logger.info("Sign out successful")
        } catch {
            Self.logger.error("Sign out failed: \(error.localizedDescription)")
            // Still update user state even if signout fails
            updateUser(nil)
            throw error
        }
    }
    
    func restoreSession() async {
        do {
            try await authService.restoreSessionFromKeychain()
            await refreshUser()
        } catch {
            Self.logger.info("No session to restore: \(error.localizedDescription)")
            updateUser(nil)
        }
    }
    
    func refreshUser() async {
        await refreshUserInternal()
    }
    
    // MARK: - Private Helpers
    
    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            
            // Initial check
            await self.refreshUserInternal()
            
            // Note: Supabase Swift SDK doesn't have a built-in auth state stream
            // We'll need to poll or use notifications. For now, we'll refresh on demand.
            // In production, you might want to set up a timer or use Supabase realtime.
        }
    }
    
    private func refreshUserInternal() async {
        guard let authService = authService as? SupabaseAuthService else {
            return
        }
        
        if let user = await authService.getCurrentUser() {
            let authenticatedUser = AuthenticatedUser(from: user)
            updateUser(authenticatedUser)
            Self.logger.info("User refreshed: \(user.id)")
        } else {
            updateUser(nil)
        }
    }
}

// MARK: - AuthenticatedUser Extension

extension AuthenticatedUser {
    init(from user: User) {
        self.id = user.id.uuidString
        self.email = user.email
        // userMetadata is non-optional in v2
        self.displayName = user.userMetadata["full_name"]?.stringValue ?? user.userMetadata["name"]?.stringValue ?? user.email
        self.firstName = user.userMetadata["first_name"]?.stringValue ?? user.userMetadata["name"]?.stringValue
        // Check multiple possible fields for avatar URL (different providers use different keys)
        if let avatarURLString = user.userMetadata["avatar_url"]?.stringValue ?? 
           user.userMetadata["picture"]?.stringValue ?? 
           user.userMetadata["photo"]?.stringValue {
            self.imageURL = URL(string: avatarURLString)
        } else {
            self.imageURL = nil
        }
    }
}

// MARK: - AnyJSON Extension for easier value extraction

extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}
