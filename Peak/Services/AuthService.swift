import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftData

enum AuthProvider: String, Sendable {
    case apple
    case google
    case email

    var displayName: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .email: "Email"
        }
    }
}

struct GoogleAuthCredential: Sendable {
    let subject: String
    let displayName: String
    let email: String
    let identityToken: String
}

@MainActor protocol AuthServiceProtocol: Sendable {
    var isSignedIn: Bool { get }
    var currentUserID: String? { get }
    var currentProvider: AuthProvider? { get }
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult
    func signUpWithEmail(email: String, password: String, displayName: String) throws -> AuthResult
    func signInWithEmail(email: String, password: String) throws -> AuthResult
    func signInWithGoogle(credential: GoogleAuthCredential) throws -> AuthResult
    func findOrCreateProfile(result: AuthResult, modelContext: ModelContext) throws -> UserProfile
    func signOut(modelContext: ModelContext) throws
    func checkCredentialState() async -> Bool
}

struct AuthResult: Sendable {
    let userID: String
    let displayName: String
    let email: String?
    let isNewUser: Bool
}

private struct EmailCredentialRecord: Codable {
    let userID: String
    let displayName: String
    let salt: String
    let passwordHash: String
}

@MainActor
final class AuthService: AuthServiceProtocol {
    private let keychain: KeychainService
    private(set) var isSignedIn: Bool = false
    private(set) var currentUserID: String?
    private(set) var currentProvider: AuthProvider?

    init(keychain: KeychainService) {
        self.keychain = keychain
        currentUserID = keychain.read(for: .currentUserID) ?? keychain.read(for: .appleUserID)
        if let stored = keychain.read(for: .authProvider) {
            currentProvider = AuthProvider(rawValue: stored)
        } else if currentUserID != nil {
            currentProvider = .apple
        }
        isSignedIn = currentUserID != nil && currentProvider != nil
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult {
        let userID = credential.user
        try keychain.save(userID, for: .appleUserID)
        if let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) {
            try keychain.save(token, for: .appleIdentityToken)
        }

        var displayName = "Peak User"
        if let fullName = credential.fullName {
            let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !parts.isEmpty { displayName = parts.joined(separator: " ") }
        }

        try beginSession(userID: userID, provider: .apple)
        PeakLogger.general.info("User signed in with Apple")
        return AuthResult(
            userID: userID,
            displayName: displayName,
            email: credential.email,
            isNewUser: credential.email != nil
        )
    }

    func signUpWithEmail(email: String, password: String, displayName: String) throws -> AuthResult {
        let normalized = try validatedEmail(email)
        try validatePassword(password)
        let cleanName = displayName.trimmed
        guard cleanName.count >= 2 else { throw PeakError.invalidInput("Enter your full name.") }

        var accounts = emailAccounts()
        guard accounts[normalized] == nil else {
            throw PeakError.authenticationFailed("An account already exists for this email.")
        }

        let salt = randomToken(byteCount: 24)
        let userID = "email:\(stableDigest(normalized))"
        accounts[normalized] = EmailCredentialRecord(
            userID: userID,
            displayName: cleanName,
            salt: salt,
            passwordHash: passwordDigest(password: password, salt: salt)
        )
        try saveEmailAccounts(accounts)
        try beginSession(userID: userID, provider: .email)
        return AuthResult(userID: userID, displayName: cleanName, email: normalized, isNewUser: true)
    }

    func signInWithEmail(email: String, password: String) throws -> AuthResult {
        let normalized = try validatedEmail(email)
        guard let account = emailAccounts()[normalized],
              account.passwordHash == passwordDigest(password: password, salt: account.salt) else {
            throw PeakError.authenticationFailed("Email or password is incorrect.")
        }
        try beginSession(userID: account.userID, provider: .email)
        return AuthResult(
            userID: account.userID,
            displayName: account.displayName,
            email: normalized,
            isNewUser: false
        )
    }

    func signInWithGoogle(credential: GoogleAuthCredential) throws -> AuthResult {
        let userID = "google:\(credential.subject)"
        try keychain.save(credential.identityToken, for: .googleIdentityToken)
        try beginSession(userID: userID, provider: .google)
        return AuthResult(
            userID: userID,
            displayName: credential.displayName.isEmpty ? "Peak User" : credential.displayName,
            email: credential.email,
            isNewUser: true
        )
    }

    func signOut(modelContext: ModelContext) throws {
        clearSession()
        PeakLogger.general.info("User signed out")
    }

    func checkCredentialState() async -> Bool {
        guard let userID = currentUserID, let currentProvider else { return false }
        guard currentProvider == .apple else { return true }

        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                let valid = state == .authorized
                if !valid {
                    Task { @MainActor in self.clearSession() }
                }
                continuation.resume(returning: valid)
            }
        }
    }

    func findOrCreateProfile(result: AuthResult, modelContext: ModelContext) throws -> UserProfile {
        let userID = result.userID
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == userID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            if existing.displayName == "Peak User" || result.isNewUser {
                existing.displayName = result.displayName
            }
            if let email = result.email { existing.email = email }
            existing.updatedAt = .now
            try modelContext.save()
            return existing
        }

        // Peak's current SwiftData graph is one private health account per local/iCloud store.
        // Never expose an existing person's health records to a different credential.
        if let otherProfile = try modelContext.fetch(FetchDescriptor<UserProfile>()).first,
           otherProfile.appleUserID != userID {
            clearSession()
            throw PeakError.authenticationFailed(
                "This Peak data store belongs to another account. Sign in with the original method or delete that account first."
            )
        }

        let profile = UserProfile(appleUserID: userID, displayName: result.displayName, email: result.email)
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }

    private func beginSession(userID: String, provider: AuthProvider) throws {
        try keychain.save(userID, for: .currentUserID)
        try keychain.save(provider.rawValue, for: .authProvider)
        currentUserID = userID
        currentProvider = provider
        isSignedIn = true
    }

    private func clearSession() {
        keychain.delete(for: .currentUserID)
        keychain.delete(for: .authProvider)
        keychain.delete(for: .appleUserID)
        keychain.delete(for: .appleIdentityToken)
        keychain.delete(for: .googleIdentityToken)
        currentUserID = nil
        currentProvider = nil
        isSignedIn = false
    }

    private func validatedEmail(_ email: String) throws -> String {
        let normalized = email.trimmed.lowercased()
        let parts = normalized.split(separator: "@")
        guard parts.count == 2, parts[0].count >= 1, parts[1].contains(".") else {
            throw PeakError.invalidInput("Enter a valid email address.")
        }
        return normalized
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8,
              password.contains(where: \.isUppercase),
              password.contains(where: \.isLowercase),
              password.contains(where: \.isNumber) else {
            throw PeakError.invalidInput("Use at least 8 characters with uppercase, lowercase, and a number.")
        }
    }

    private func emailAccounts() -> [String: EmailCredentialRecord] {
        guard let encoded = keychain.read(for: .emailAccounts),
              let data = encoded.data(using: .utf8),
              let accounts = try? JSONDecoder().decode([String: EmailCredentialRecord].self, from: data) else {
            return [:]
        }
        return accounts
    }

    private func saveEmailAccounts(_ accounts: [String: EmailCredentialRecord]) throws {
        let data = try JSONEncoder().encode(accounts)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw PeakError.authenticationFailed("Could not secure this account.")
        }
        try keychain.save(encoded, for: .emailAccounts)
    }

    private func randomToken(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private func stableDigest(_ value: String) -> String {
        Data(SHA256.hash(data: Data(value.utf8))).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func passwordDigest(password: String, salt: String) -> String {
        var digest = Data((salt + password).utf8)
        for _ in 0..<20_000 {
            digest = Data(SHA256.hash(data: digest))
        }
        return digest.base64EncodedString()
    }
}
