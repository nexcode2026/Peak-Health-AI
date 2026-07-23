import AuthenticationServices
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var recoveryTarget = PeakConstants.Defaults.recoveryTarget
    @State private var waterGoal = PeakConstants.Defaults.dailyWaterML
    @State private var sleepTarget = PeakConstants.Defaults.sleepHoursTarget
    @State private var loadSampleData = true
    @State private var enableFaceID = false
    @State private var error: PeakError?

    let onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        ZStack {
            PeakTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, PeakTheme.Spacing.lg)
                    .padding(.top, PeakTheme.Spacing.md)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    goalsStep.tag(1)
                    permissionsStep.tag(2)
                    faceIDStep.tag(3)
                    signInStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PeakTheme.surfaceElevated)
                Capsule()
                    .fill(PeakTheme.accentGradient)
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
            }
        }
        .frame(height: 4)
    }

    private var welcomeStep: some View {
        onboardingPage(
            icon: "mountain.2.fill",
            title: "Welcome to Peak",
            subtitle: "Your personal recovery & performance companion. Track, understand, and optimize your peak."
        ) {
            Button("Get Started") { step = 1 }
                .buttonStyle(PeakPrimaryButtonStyle())
        }
    }

    private var goalsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.lg) {
                Text("Set Your Goals")
                    .font(PeakTheme.Typography.largeTitle)
                    .foregroundStyle(PeakTheme.textPrimary)

                goalSlider(title: "Recovery Target", value: "\(recoveryTarget)", binding: Binding(
                    get: { Double(recoveryTarget) },
                    set: { recoveryTarget = Int($0) }
                ), range: 50...95)

                goalSlider(title: "Daily Water (ml)", value: "\(waterGoal)", binding: Binding(
                    get: { Double(waterGoal) },
                    set: { waterGoal = Int($0) }
                ), range: 1500...4000, step: 250)

                goalSlider(title: "Sleep Target (hours)", value: sleepTarget.formattedOneDecimal, binding: Binding(
                    get: { sleepTarget },
                    set: { sleepTarget = $0 }
                ), range: 6...10, step: 0.5)

                Toggle("Load sample data for instant insights", isOn: $loadSampleData)
                    .tint(PeakTheme.coral)

                Button("Continue") { step = 2 }
                    .buttonStyle(PeakPrimaryButtonStyle())
            }
            .padding(PeakTheme.Spacing.lg)
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            Text("Permissions")
                .font(PeakTheme.Typography.largeTitle)
                .foregroundStyle(PeakTheme.textPrimary)

            permissionRow(icon: "heart.fill", title: "Health", detail: "Sleep, HRV, activity for recovery scoring")
            permissionRow(icon: "bell.fill", title: "Notifications", detail: "Habit, hydration & wind-down reminders")
            permissionRow(icon: "icloud.fill", title: "iCloud", detail: "Private sync across your devices")

            DisclaimerBanner()

            Button("Grant Permissions") {
                Task { await requestPermissions() }
            }
            .buttonStyle(PeakPrimaryButtonStyle())

            Button("Skip for now") { step = 3 }
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .padding(PeakTheme.Spacing.lg)
    }

    private var faceIDStep: some View {
        onboardingPage(
            icon: "faceid",
            title: "Quick Unlock",
            subtitle: "Use \(container.biometrics.biometricType) for fast, secure access to Peak."
        ) {
            VStack(spacing: PeakTheme.Spacing.md) {
                Toggle("Enable \(container.biometrics.biometricType)", isOn: $enableFaceID)
                    .tint(PeakTheme.coral)
                    .disabled(!container.biometrics.isAvailable)

                Button("Continue") { step = 4 }
                    .buttonStyle(PeakPrimaryButtonStyle())
            }
        }
    }

    private var signInStep: some View {
        VStack(spacing: PeakTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "mountain.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(PeakTheme.heroGradient)

            Text("Sign in to Peak")
                .font(PeakTheme.Typography.largeTitle)
                .foregroundStyle(PeakTheme.textPrimary)

            Text("Your data stays private. Sign in with Apple — we never see your password.")
                .font(PeakTheme.Typography.body)
                .foregroundStyle(PeakTheme.textSecondary)
                .multilineTextAlignment(.center)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))

            if let error {
                Text(error.localizedDescription)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.error)
            }

            DisclaimerBanner()

            Spacer()
        }
        .padding(PeakTheme.Spacing.lg)
    }

    @ViewBuilder
    private func onboardingPage(icon: String, title: String, subtitle: String, @ViewBuilder action: () -> some View) -> some View {
        VStack(spacing: PeakTheme.Spacing.xl) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(PeakTheme.heroGradient)
            VStack(spacing: PeakTheme.Spacing.sm) {
                Text(title)
                    .font(PeakTheme.Typography.largeTitle)
                    .foregroundStyle(PeakTheme.textPrimary)
                Text(subtitle)
                    .font(PeakTheme.Typography.body)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            action()
            Spacer()
        }
        .padding(PeakTheme.Spacing.lg)
    }

    private func goalSlider(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
            HStack {
                Text(title).font(PeakTheme.Typography.headline)
                Spacer()
                Text(value).foregroundStyle(PeakTheme.coral)
            }
            Slider(value: binding, in: range, step: step)
                .tint(PeakTheme.coral)
        }
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: PeakTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(PeakTheme.teal)
                .frame(width: 40)
            VStack(alignment: .leading) {
                Text(title).font(PeakTheme.Typography.headline)
                Text(detail).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            }
            Spacer()
        }
        .padding(PeakTheme.Spacing.md)
        .background(PeakTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
    }

    private func requestPermissions() async {
        _ = try? await container.healthKit.requestAuthorization()
        _ = await container.notifications.requestAuthorization()
        step = 3
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                do {
                    let authResult = try await container.auth.signInWithApple(credential: credential)
                    let profile = try (container.auth as! AuthService).findOrCreateProfile(result: authResult, modelContext: modelContext)
                    profile.recoveryTarget = recoveryTarget
                    profile.dailyWaterGoalML = waterGoal
                    profile.sleepHoursTarget = sleepTarget
                    profile.faceIDEnabled = enableFaceID
                    profile.onboardingCompleted = true
                    profile.updatedAt = Date()

                    if loadSampleData {
                        SampleDataGenerator.populate(context: modelContext, profile: profile)
                    }

                    container.notifications.configure(profile: profile)
                    onComplete()
                } catch let e as PeakError {
                    error = e
                } catch {
                    self.error = .unknown(error.localizedDescription)
                }
            }
        case .failure(let err):
            error = .authenticationFailed(err.localizedDescription)
        }
    }
}