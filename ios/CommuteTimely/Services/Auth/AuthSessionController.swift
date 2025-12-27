//
// AuthSessionController.swift
// CommuteTimely
//
// Lightweight bridge between the app and Supabase authentication.
//

import Foundation
import Combine
import OSLog

// MARK: - Models

struct AuthenticatedUser: Equatable {
    let id: String
    let email: String?
    let displayName: String?
    let firstName: String?
    let imageURL: URL?
}

enum AuthSessionState: Equatable {
    case signedOut
    case signedIn(AuthenticatedUser)
}

// MARK: - Base Controller

@MainActor
class AuthSessionController: ObservableObject {
    @Published private(set) var currentUser: AuthenticatedUser?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    
    private let stateSubject = CurrentValueSubject<AuthSessionState, Never>(.signedOut)
    
    var authStatePublisher: AnyPublisher<AuthSessionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    func idToken(template: String? = nil) async throws -> String? {
        fatalError("Subclasses must override idToken(template:)")
    }
    
    func signOut() async throws {
        fatalError("Subclasses must override signOut()")
    }
    
    func updateUser(_ user: AuthenticatedUser?) {
        currentUser = user
        isAuthenticated = user != nil
        stateSubject.send(user.map { .signedIn($0) } ?? .signedOut)
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
}

// MARK: - Mock Provider (for testing)

@MainActor
final class SupabaseMockAuthController: AuthSessionController {
    private var tokenValue: String
    
    init(initialUser: AuthenticatedUser? = nil, token: String = "mock-token") {
        self.tokenValue = token
        super.init()
        updateUser(initialUser)
    }
    
    override func idToken(template: String? = nil) async throws -> String? {
        tokenValue
    }
    
    override func signOut() async throws {
        updateUser(nil)
    }
    
    func completeMockSignIn(
        name: String = "Mock Rider",
        email: String = "mock.user@commute.timely",
        firstName: String? = "Mock"
    ) {
        let user = AuthenticatedUser(
            id: UUID().uuidString,
            email: email,
            displayName: name,
            firstName: firstName,
            imageURL: nil
        )
        updateUser(user)
    }
    
    func setMockToken(_ token: String) {
        tokenValue = token
    }
}

