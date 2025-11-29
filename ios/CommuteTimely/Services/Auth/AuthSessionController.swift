//
// AuthSessionController.swift
// CommuteTimely
//
// Lightweight bridge between the app and Clerk authentication.
//

import Foundation
import Combine
#if canImport(Clerk)
import Clerk
#endif

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

#if canImport(Clerk)
// MARK: - Clerk Adapter

@MainActor
final class ClerkAuthController: AuthSessionController {
    private let clerk: Clerk
    private var authEventsTask: Task<Void, Never>?
    
    init(clerk: Clerk = .shared) {
        self.clerk = clerk
        super.init()
        refreshFromClerk()
        observeAuthEvents()
    }
    
    @MainActor
    deinit {
        // Task cancellation is safe from deinit
        authEventsTask?.cancel()
    }
    
    override func idToken(template: String? = nil) async throws -> String? {
        guard let session = clerk.session else { return nil }
        let token = try await session.getToken(.init(template: template))
        return token?.jwt
    }
    
    override func signOut() async throws {
        try await clerk.signOut()
        refreshFromClerk()
    }
    
    func reloadCachedSession() {
        refreshFromClerk()
    }
    
    private func observeAuthEvents() {
        authEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in clerk.authEventEmitter.events {
                switch event {
                case .signInCompleted, .signUpCompleted:
                    refreshFromClerk()
                case .signedOut:
                    updateUser(nil)
                }
            }
        }
    }
    
    private func refreshFromClerk() {
        guard let user = clerk.user else {
            updateUser(nil)
            return
        }
        let profile = AuthenticatedUser(user: user)
        updateUser(profile)
    }
}
#endif

// MARK: - Mock Provider

@MainActor
final class ClerkMockProvider: AuthSessionController {
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

// MARK: - Helpers

#if canImport(Clerk)
private extension AuthenticatedUser {
    init(user: User) {
        self.id = user.id
        self.email = user.primaryEmailAddress?.emailAddress ?? user.emailAddresses.first?.emailAddress
        self.firstName = user.firstName
        if let firstName = user.firstName, let lastName = user.lastName {
            self.displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        } else if let firstName = user.firstName ?? user.username {
            self.displayName = firstName
        } else {
            self.displayName = user.emailAddresses.first?.emailAddress
        }
        self.imageURL = URL(string: user.imageUrl)
    }
}
#endif

