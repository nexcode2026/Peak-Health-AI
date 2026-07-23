import AuthenticationServices
import Foundation
import SwiftData

// MARK: - Authentication Protocol

protocol AuthServiceProtocol: Sendable {
    var isSignedIn: Bool { get }
    var currentUserID: String? { get }
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult
    func signOut(modelContext: ModelContext) throws
    func checkCredentialState() async -> Bool
}

struct AuthResult: Sendable {
    let userID: String
    let displayName: String
    let email: String?
    let isNewUser: Bool
}

// MARK: - Sign in with Apple Service

@MainActor
final class AuthService: AuthServiceProtocol {
    private let keychain: KeychainService
    private(set) var isSignedIn: Bool = false
    private(set) var currentUserID: String?

    init(keychain: KeychainService) {
        self.keychain = keychain
        currentUserID = keychain.read(for: .appleUserID)
        isSignedIn = currentUserID != nil
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult {
        let userID = credential.user

        try keychain.save(userID, for: .appleUserID)
        if let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) {
            try keychain.save(token, for: .appleIdentityToken)
        }

        currentUserID = userID
        isSignedIn = true

        var displayName = "Peak User"
        if let fullName = credential.fullName {
            let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !parts.isEmpty { displayName = parts.joined(separator: " ") }
        }

        PeakLogger.general.info("User signed in with Apple: \(userID)")

        return AuthResult(
            userID: userID,
            displayName: displayName,
            email: credential.email,
            isNewUser: credential.email != nil
        )
    }

    func signOut(modelContext: ModelContext) throws {
        keychain.deleteAll()
        currentUserID = nil
        isSignedIn = false
        PeakLogger.general.info("User signed out")
    }

    func checkCredentialState() async -> Bool {
        guard let userID = currentUserID else { return false }

        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                let valid = state == .authorized
                if !valid {
                    Task { @MainActor in
                        self.isSignedIn = false
                        self.currentUserID = nil
                    }
                }
                continuation.resume(returning: valid)
            }
        }
    }

    func findOrCreateProfile(
        result: AuthResult,
        modelContext: ModelContext
    ) throws -> UserProfile {
        let userID = result.userID
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == userID }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.displayName = result.displayName
            if let email = result.email { existing.email = email }
            existing.updatedAt = Date()
            return existing
        }

        let profile = UserProfile(
            appleUserID: userID,
            displayName: result.displayName,
            email: result.email
        )
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }
}