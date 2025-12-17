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
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

extension SupabaseError {
    static func from(error: Error, logger: Logger? = nil) -> SupabaseError {
        if let urlError = error as? URLError {
            if urlError.code == .notConnectedToInternet {
                return .offline
            } else {
                return .networkFailure(urlError.localizedDescription)
            }
        }

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

        let nsError = error as NSError
        logger?.error("Unknown Supabase error domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .public)")
        return .unknown(nsError.localizedDescription)
    }
}
