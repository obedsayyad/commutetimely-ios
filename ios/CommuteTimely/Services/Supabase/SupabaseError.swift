//
// SupabaseError.swift
// CommuteTimely
//
// Centralized error type and mapping helpers for Supabase operations.
//

import Foundation
import Supabase
import OSLog

enum SupabaseError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case badRequest(String?)
    case decodingFailed(String?)
    case networkFailure(String?)
    case offline
    case rlsViolation(String?)
    case invalidResponse
    case authError(String)  // NEW: Explicit auth error handling
    case unknown(String?)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested data could not be found."
        case .conflict:
            return "This action conflicts with existing data."
        case .badRequest(let message):
            return message ?? "The request was invalid."
        case .decodingFailed:
            return "I couldn't understand the data from the server."
        case .networkFailure:
            return "I couldn't connect to the network."
        case .offline:
            return "You're offline. Showing your last saved data."
        case .rlsViolation:
            return "You don't have access to this data."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .authError(let message):
            // Show actual auth error in production (sanitized by Supabase SDK)
            return "Authentication failed: \(message)"
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

extension SupabaseError {
    static func from(error: Error, logger: Logger? = nil) -> SupabaseError {
        // FIRST: Check for URL/network errors
        if let urlError = error as? URLError {
            if urlError.code == .notConnectedToInternet {
                return .offline
            } else {
                logger?.error("⚠️ URLError: code=\(urlError.code.rawValue) desc=\(urlError.localizedDescription)")
                return .networkFailure(urlError.localizedDescription)
            }
        }
        
        // SECOND: Check for Supabase AuthError (CRITICAL - was missing!)
        // The Supabase SDK throws AuthError for OAuth, invalid credentials, etc.
        let nsError = error as NSError
        
        // AuthError typically comes as NSError with specific domain/code
        // Check common auth failure patterns
        if nsError.domain.contains("Auth") || nsError.domain.contains("Supabase") {
            let errorMessage = error.localizedDescription
            logger?.error("🔐 Supabase AuthError: domain=\(nsError.domain) code=\(nsError.code) message=\(errorMessage)")
            
            #if DEBUG
            print("[SupabaseError] 🔐 AuthError detected")
            print("[SupabaseError]    Domain: \(nsError.domain)")
            print("[SupabaseError]    Code: \(nsError.code)")
            print("[SupabaseError]    UserInfo: \(nsError.userInfo)")
            #endif
            
            // Return specific auth error
            return .authError(errorMessage)
        }
        
        // THIRD: Check HTTP status codes (from Supabase HTTP responses)
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            logger?.error("🌐 Underlying error: domain=\(underlyingError.domain) code=\(underlyingError.code)")
            
            // HTTP errors are wrapped - extract status code if available
            if let statusCode = nsError.userInfo["statusCode"] as? Int ?? underlyingError.userInfo["statusCode"] as? Int {
                logger?.error("📡 HTTP Status Code: \(statusCode)")
                
                switch statusCode {
                case 400:
                    return .badRequest(nsError.localizedDescription)
                case 401:
                    return .unauthorized
                case 403:
                    return .forbidden
                case 404:
                    return .notFound
                default:
                    return .unknown(nsError.localizedDescription)
                }
            }
        }

        // FOURTH: PostgrestError (database errors)
        if let postgrestError = error as? PostgrestError {
            // In Supabase v2, code is a String, not optional
            let code = postgrestError.code ?? ""
            logger?.error("Supabase PostgrestError: code=\(code, privacy: .public) message=\(postgrestError.message, privacy: .public)")

            switch code {
            case "PGRST301": // JWT expired / invalid
                return .unauthorized
            case "PGRST302": // RLS error / forbidden
                return .rlsViolation(postgrestError.message)
            case "PGRST303":
                return .forbidden
            case "PGRST304":
                return .notFound
            default:
                return .badRequest(postgrestError.message)
            }
        }

        // FIFTH: Fallback with detailed logging for debugging
        logger?.error("❌ Unhandled Supabase error: domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .public)")
        
        #if DEBUG
        print("[SupabaseError] ❌ UNHANDLED ERROR - Please add specific handling for this case:")
        print("[SupabaseError]    Type: \(type(of: error))")
        print("[SupabaseError]    Domain: \(nsError.domain)")
        print("[SupabaseError]    Code: \(nsError.code)")
        print("[SupabaseError]    Description: \(nsError.localizedDescription)")
        print("[SupabaseError]    UserInfo: \(nsError.userInfo)")
        print("[SupabaseError]    Full error: \(error)")
        #endif
        
        return .unknown(nsError.localizedDescription)
    }
}
