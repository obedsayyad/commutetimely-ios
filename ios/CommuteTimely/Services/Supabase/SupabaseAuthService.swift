//
// SupabaseAuthService.swift
// CommuteTimely
//
// Supabase authentication service implementation
//

import Foundation
import Supabase
import OSLog

final class SupabaseAuthService: SupabaseAuthServiceProtocol {
    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "AuthService")
    
    init(client: SupabaseClient) {
        self.client = client
        Self.logger.info("SupabaseAuthService initialized")
        logConfiguration()
    }
    
    // MARK: - Diagnostic Logging
    
    private func logConfiguration() {
        let url = AppSecrets.supabaseURL
        let keyPrefix = String(AppSecrets.supabaseAnonKey.prefix(15))
        
        Self.logger.info("Supabase URL: \(url)")
        Self.logger.info("Supabase Key prefix: \(keyPrefix)...")
        
        #if DEBUG
        print("[SupabaseAuth] Service initialized")
        print("[SupabaseAuth] URL: \(url)")
        print("[SupabaseAuth] Key: \(keyPrefix)...")
        #endif
        
        // Validate URL format
        if !url.hasPrefix("https://") {
            Self.logger.error("⚠️ Invalid Supabase URL - must start with https://")
            print("[SupabaseAuth] ⚠️ WARNING: Invalid URL format")
        }
        
        // Validate key format
        if AppSecrets.supabaseAnonKey.isEmpty {
            Self.logger.error("⚠️ Supabase key is empty")
            print("[SupabaseAuth] ⚠️ WARNING: Empty Supabase key")
        }
    }
    
    private func logError(_ operation: String, error: Error) {
        let errorDescription = error.localizedDescription
        Self.logger.error("\(operation) failed: \(errorDescription)")
        
        #if DEBUG
        print("[SupabaseAuth] ❌ \(operation) failed: \(errorDescription)")
        
        // Provide diagnostic hints
        if errorDescription.contains("Invalid API key") || errorDescription.contains("apikey") {
            print("[SupabaseAuth] 💡 Hint: Check if the Supabase API key is correct")
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            print("[SupabaseAuth] 💡 Hint: Check network connectivity")
        } else if errorDescription.contains("RLS") || errorDescription.contains("policy") {
            print("[SupabaseAuth] 💡 Hint: Check Row Level Security policies")
        } else if errorDescription.contains("not found") || errorDescription.contains("404") {
            print("[SupabaseAuth] 💡 Hint: Check if the Supabase URL is correct")
        } else if errorDescription.contains("unauthorized") || errorDescription.contains("401") {
            print("[SupabaseAuth] 💡 Hint: Session may have expired, try signing in again")
        }
        #endif
    }
    
    private func logSuccess(_ operation: String, details: String = "") {
        Self.logger.info("\(operation) successful\(details.isEmpty ? "" : ": \(details)")")
        #if DEBUG
        print("[SupabaseAuth] ✅ \(operation) successful\(details.isEmpty ? "" : ": \(details)")")
        #endif
    }
    
    func signUp(email: String, password: String) async throws {
        #if DEBUG
        print("[SupabaseAuth] Attempting sign up for: \(email)")
        #endif
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            logSuccess("Sign up", details: "email: \(email)")
            
            // Save session if available
            if let session = response.session {
                try await saveSession(session)
            }
        } catch {
            logError("Sign up", error: error)
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        #if DEBUG
        print("[SupabaseAuth] Attempting sign in for: \(email)")
        #endif
        
        do {
            // signIn returns Session directly in v2
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            logSuccess("Sign in", details: "email: \(email)")
            
            try await saveSession(session)
        } catch {
            logError("Sign in", error: error)
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func sendMagicLink(email: String) async throws {
        #if DEBUG
        print("[SupabaseAuth] Sending magic link to: \(email)")
        #endif
        
        do {
            // Use the app's custom URL scheme for the redirect
            // This allows the app to handle the callback when user clicks the magic link
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "commutetimely://auth/callback")
            )
            Self.logger.info("Magic link sent to: \(email, privacy: .private)")
            #if DEBUG
            print("[SupabaseAuth] ✅ Magic link sent successfully")
            print("[SupabaseAuth] 💡 Redirect URL: commutetimely://auth/callback")
            #endif
        } catch {
            Self.logger.error("Magic link failed: \(error.localizedDescription)")
            #if DEBUG
            print("[SupabaseAuth] ❌ Magic link failed: \(error.localizedDescription)")
            #endif
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            // signInWithIdToken returns Session directly in v2
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            
            Self.logger.info("Apple sign in successful")
            
            try await saveSession(session)
        } catch {
            Self.logger.error("Apple sign in failed: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func signInWithGoogle(idToken: String) async throws {
        do {
            // signInWithIdToken returns Session directly in v2
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken
                )
            )
            
            Self.logger.info("Google sign in successful")
            
            try await saveSession(session)
        } catch {
            Self.logger.error("Google sign in failed: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func signOut() async throws {
        do {
            try await client.auth.signOut()
            try KeychainHelper.delete()
            Self.logger.info("Sign out successful")
        } catch {
            Self.logger.error("Sign out failed: \(error.localizedDescription)")
            // Still clear keychain even if Supabase signout fails
            try? KeychainHelper.delete()
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func restoreSessionFromKeychain() async throws {
        guard let data = try? KeychainHelper.load(),
              let sessionData = try? JSONDecoder().decode(SessionData.self, from: data) else {
            Self.logger.info("No saved session found in Keychain")
            return
        }
        
        do {
            // In Supabase v2, we use setSession with accessToken and refreshToken
            try await client.auth.setSession(
                accessToken: sessionData.accessToken,
                refreshToken: sessionData.refreshToken
            )
            Self.logger.info("Session restored from Keychain")
        } catch {
            Self.logger.warning("Failed to restore session: \(error.localizedDescription)")
            // Clear invalid session
            try? KeychainHelper.delete()
            throw SupabaseError.unauthorized
        }
    }
    
    func getCurrentSession() async -> Session? {
        #if DEBUG
        print("[SupabaseAuth] Getting current session...")
        #endif
        
        do {
            let session = try await client.auth.session
            #if DEBUG
            print("[SupabaseAuth] ✅ Session found - User ID: \(session.user.id)")
            #endif
            return session
        } catch {
            #if DEBUG
            print("[SupabaseAuth] ℹ️ No active session: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    func getCurrentUser() async -> User? {
        #if DEBUG
        print("[SupabaseAuth] Getting current user...")
        #endif
        
        do {
            // In Supabase v2, user() is a function
            let user = try await client.auth.user()
            #if DEBUG
            print("[SupabaseAuth] ✅ User found - ID: \(user.id)")
            #endif
            return user
        } catch {
            #if DEBUG
            print("[SupabaseAuth] ℹ️ No current user: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Test the Supabase connection by attempting to get the current session
    func testConnection() async -> Bool {
        #if DEBUG
        print("[SupabaseAuth] Testing Supabase connection...")
        #endif
        
        do {
            // Try to access auth - this will fail if connection is bad
            _ = try await client.auth.session
            #if DEBUG
            print("[SupabaseAuth] ✅ Connection test passed (session exists)")
            #endif
            return true
        } catch {
            // Even if no session, connection might still work
            // Try a simple operation to verify
            #if DEBUG
            print("[SupabaseAuth] ℹ️ No session, but connection may still be valid")
            #endif
            return true
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveSession(_ session: Session) async throws {
        let sessionData = SessionData(
            accessToken: session.accessToken,
            tokenType: session.tokenType,
            expiresIn: session.expiresIn,
            expiresAt: session.expiresAt,
            refreshToken: session.refreshToken,
            user: session.user
        )
        
        let data = try JSONEncoder().encode(sessionData)
        try KeychainHelper.save(data)
    }
}

// MARK: - Session Storage Model

private struct SessionData: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Double
    let expiresAt: Double
    let refreshToken: String
    let user: User
}
