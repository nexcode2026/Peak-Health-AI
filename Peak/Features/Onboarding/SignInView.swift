import AuthenticationServices
import CryptoKit
import Security
import SwiftData
import SwiftUI
import UIKit

struct SignInView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var error: PeakError?
    @State private var isWorking = false
    @State private var googleOAuth = GoogleOAuthSession()

    let onSignedIn: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PeakTheme.background, PeakTheme.midnight.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            AnimatedMeshBackground().opacity(0.72).ignoresSafeArea()

            ScrollView {
                VStack(spacing: PeakTheme.Spacing.xl) {
                    brandHeader
                    providerButtons

                    if let error {
                        Text(error.localizedDescription)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.error)
                            .multilineTextAlignment(.center)
                    }

                    privacyPromise
                    DisclaimerBanner(compact: true)
                }
                .padding(PeakTheme.Spacing.lg)
                .safeAreaPadding(.vertical, PeakTheme.Spacing.lg)
            }

            if isWorking {
                Color.black.opacity(0.16).ignoresSafeArea()
                ProgressView("Securing your private account…")
                    .padding(PeakTheme.Spacing.lg)
                    .glassCard(tint: PeakTheme.electricBlue.opacity(0.10))
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            Image("AppIconPreviewPrimary")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: PeakTheme.electricBlue.opacity(0.35), radius: 24, y: 12)

            Text("Your health. One private account.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text("Continue with Apple or Google. New members create a Peak account automatically; returning members reconnect to their existing profile.")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var providerButtons: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
            .disabled(isWorking)

            Button { authenticateWithGoogle() } label: {
                HStack(spacing: PeakTheme.Spacing.sm) {
                    Text("G")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(PeakTheme.spectralGradient)
                        .frame(width: 28, height: 28)
                        .background(.white, in: Circle())
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .contentShape(Rectangle())
            }
            .foregroundStyle(PeakTheme.textPrimary)
            .glassCard(cornerRadius: PeakTheme.Radius.md, tint: .white.opacity(0.08), interactive: true)
            .disabled(isWorking)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(tint: PeakTheme.ultraviolet.opacity(0.07))
    }

    private var privacyPromise: some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                Label("Account required", systemImage: "person.crop.circle.badge.checkmark")
                Spacer()
                Label("iCloud ready", systemImage: "icloud.and.arrow.up")
            }
            .font(PeakTheme.Typography.caption)
            .foregroundStyle(PeakTheme.mint)

            Text("Peak never sells your health data. By continuing, you agree to the Terms of Service and Privacy Policy.")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard()
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            isWorking = true
            Task {
                defer { isWorking = false }
                do {
                    let result = try await container.auth.signInWithApple(credential: credential)
                    try completeSignIn(result)
                } catch let peakError as PeakError {
                    error = peakError
                } catch {
                    self.error = .unknown(error.localizedDescription)
                }
            }
        case .failure(let error):
            self.error = .authenticationFailed(error.localizedDescription)
        }
    }

    private func authenticateWithGoogle() {
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                let credential = try await googleOAuth.signIn()
                let result = try container.auth.signInWithGoogle(credential: credential)
                try completeSignIn(result)
            } catch let peakError as PeakError {
                error = peakError
            } catch {
                self.error = .authenticationFailed(error.localizedDescription)
            }
        }
    }

    private func completeSignIn(_ result: AuthResult) throws {
        _ = try container.auth.findOrCreateProfile(result: result, modelContext: modelContext)
        OnboardingStorage.cloudKitSyncEnabled = true
        try? modelContext.save()
        PeakHaptics.success()
        onSignedIn()
    }
}

@MainActor
final class GoogleOAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var webSession: ASWebAuthenticationSession?

    func signIn() async throws -> GoogleAuthCredential {
        guard let clientID = configuredValue("GOOGLE_CLIENT_ID"),
              let redirectScheme = configuredValue("GOOGLE_REDIRECT_SCHEME") else {
            throw PeakError.authenticationFailed(
                "Google Sign-In needs GOOGLE_CLIENT_ID and GOOGLE_REDIRECT_SCHEME in the Peak target configuration."
            )
        }

        let redirectURI = "\(redirectScheme):/oauthredirect"
        let verifier = randomURLSafeToken()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomURLSafeToken()
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: redirectScheme) { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: PeakError.authenticationFailed("Google did not return an account.")) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            if !session.start() {
                continuation.resume(throwing: PeakError.authenticationFailed("Could not open Google Sign-In."))
            }
        }

        let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        guard callback?.queryItems?.first(where: { $0.name == "state" })?.value == state,
              let code = callback?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw PeakError.authenticationFailed("Google Sign-In response could not be verified.")
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = payload["id_token"] as? String,
              let claims = decodeJWTClaims(idToken),
              let subject = claims["sub"] as? String,
              let email = claims["email"] as? String else {
            throw PeakError.authenticationFailed("Google could not verify this account.")
        }
        return GoogleAuthCredential(
            subject: subject,
            displayName: claims["name"] as? String ?? "Peak User",
            email: email,
            identityToken: idToken
        )
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func configuredValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$("),
              !value.localizedCaseInsensitiveContains("REPLACE_ME") else { return nil }
        return value
    }

    private func randomURLSafeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func formBody(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = values.map { key, value in
            "\(key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    private func decodeJWTClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
