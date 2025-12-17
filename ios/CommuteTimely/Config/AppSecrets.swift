//
// AppSecrets.swift
// CommuteTimely
//
// Centralized configuration for API keys and secrets
//
// ⚠️ IMPORTANT: Replace the placeholder Supabase anon key with your real key!
// - Supabase: Get from https://app.supabase.com/project/_/settings/api
// - RevenueCat: Get from https://app.revenuecat.com/projects
//
// 🔒 SECURITY: Never commit real production keys to version control.
// Consider using environment variables or a secrets management system for production.
//

import Foundation

struct AppSecrets {
    // MARK: - Supabase Configuration
    
    /// Supabase project URL
    /// Verified: https://dvvmlhfyabbfcvrohjip.supabase.co
    static let supabaseURL = "https://dvvmlhfyabbfcvrohjip.supabase.co"
    
    /// Supabase anonymous (public) key
    /// ⚠️ IMPORTANT: This MUST be a valid JWT token starting with "eyJ"
    /// Get from: Supabase Dashboard → Project Settings → API → anon (public) key
    /// The key below is a PLACEHOLDER - replace with your real anon key!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR2dm1saGZ5YWJiZmN2cm9oamlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4ODQ5OTIsImV4cCI6MjA4MTQ2MDk5Mn0.NX0TDGVzltKOPD6d5DBL9weFqoGx-_YxoZufZ2cdzkw"
    
    // MARK: - Key Validation
    
    /// Validates that the Supabase anon key appears to be a valid JWT
    static var isSupabaseKeyValid: Bool {
        // Valid Supabase anon keys are JWTs that start with "eyJ" (base64 for {"alg":...)
        // and should NOT contain placeholder text
        return supabaseAnonKey.hasPrefix("eyJ") && 
               !supabaseAnonKey.contains("REPLACE_WITH") &&
               supabaseAnonKey.components(separatedBy: ".").count == 3
    }
    
    // MARK: - RevenueCat Configuration
    
    /// RevenueCat public API key (SDK Key)
    /// Get from: RevenueCat Dashboard → Projects → [Your App] → API Keys
    /// Format: Starts with "appl_" for production or test prefix for sandbox
    static let revenueCatPublicAPIKey = "test_dTYrdOBLnXSzoCGrKGqHwaQQYXk"
}
