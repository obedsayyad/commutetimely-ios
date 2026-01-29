//
// AuthViewModel.swift
// CommuteTimely
//
// ViewModel for Supabase authentication flows
//

import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Combine
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingMagicLinkSent = false
    
    private let authService: SupabaseAuthServiceProtocol
    private let authManager: AuthSessionController
    private var storedNonce: String?
    
    init(authService: SupabaseAuthServiceProtocol, authManager: AuthSessionController) {
        self.authService = authService
        self.authManager = authManager
    }
    
    func signUp() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password)
            // Auth state will update via authManager
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            // Refresh auth state
            if let controller = authManager as? SupabaseAuthController {
                await controller.refreshUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func sendMagicLink() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.sendMagicLink(email: email)
            showingMagicLinkSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signInWithApple() async {
        // This method is kept for programmatic Apple Sign-In if needed
        // Check network connection first
        if !NetworkMonitor.shared.checkConnection() {
            errorMessage = "No internet connection. Please check your network and try again."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(
            nonce: nonce,
            onSuccess: { [weak self] idToken, nonce in
                Task { @MainActor in
                    await self?.handleAppleSignIn(idToken: idToken, nonce: nonce)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        )
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = delegate
        
        authorizationController.performRequests()
    }
    
    func handleAppleAuthorizationResult(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = "Unable to fetch identity token"
                    isLoading = false
                    return
                }
                
                await handleAppleSignIn(idToken: idTokenString, nonce: nonce)
            } else {
                errorMessage = "Invalid authorization credential"
                isLoading = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        guard let clientID = getGoogleClientID() else {
            errorMessage = "Google Sign-In not configured"
            isLoading = false
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present Google Sign-In"
            isLoading = false
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID token"])
            }
            
            try await authService.signInWithGoogle(idToken: idToken)
            
            if let controller = authManager as? SupabaseAuthController {
                await controller.refreshUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func handleAppleSignIn(idToken: String, nonce: String) async {
        do {
            try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            if let controller = authManager as? SupabaseAuthController {
                await controller.refreshUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func getGoogleClientID() -> String? {
        // Read from Info.plist using the key defined in project.pbxproj
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        // Also try the standard Info.plist key
        if let clientID = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String {
            return clientID
        }
        return nil
    }
    
    // MARK: - Crypto Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    func generateNonce() -> String {
        return randomNonceString()
    }
    
    func setStoredNonce(_ nonce: String) {
        storedNonce = nonce
    }
    
    func getStoredNonce() -> String? {
        return storedNonce
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

// MARK: - Apple Sign-In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let nonce: String
    let onSuccess: (String, String) -> Void
    let onError: (Error) -> Void
    
    init(nonce: String, onSuccess: @escaping (String, String) -> Void, onError: @escaping (Error) -> Void) {
        self.nonce = nonce
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                onError(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]))
                return
            }
            
            onSuccess(idTokenString, nonce)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onError(error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the active window scene
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        
        guard let window = windowScene?.windows.first(where: { $0.isKeyWindow })
                ?? windowScene?.windows.first else {
            // Fallback that shouldn't happen in a properly set up app
            return ASPresentationAnchor()
        }
        return window
    }
}


