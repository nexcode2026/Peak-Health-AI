import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProfileViewModel()
    @State private var showPaywall = false
    @State private var showGoalsSheet = false
    @State private var grokAPIKey = ""

    var body: some View {
        NavigationStack {
            List {
                profileHeader
                membershipSection
                goalsSection
                notificationsSection
                privacySection
                aiSection
                aboutSection
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showGoalsSheet) { goalsSheet }
            .sheet(isPresented: .init(get: { viewModel.exportURL != nil }, set: { if !$0 { viewModel.exportURL = nil } })) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Delete Account?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    try? viewModel.deleteAccount(modelContext: modelContext, container: container)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all your Peak data. This cannot be undone.")
            }
        }
        .onAppear { viewModel.load(modelContext: modelContext, container: container) }
    }

    private var profileHeader: some View {
        Section {
            HStack(spacing: PeakTheme.Spacing.md) {
                Circle()
                    .fill(PeakTheme.heroGradient)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(String(viewModel.profile?.displayName.prefix(1) ?? "P"))
                            .font(PeakTheme.Typography.title)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading) {
                    Text(viewModel.profile?.displayName ?? "Peak User")
                        .font(PeakTheme.Typography.title)
                    Text(container.currentTier.displayName)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.coral)
                }
            }
            .listRowBackground(PeakTheme.surface)
        }
    }

    private var membershipSection: some View {
        Section("Membership") {
            if container.currentTier == .free {
                Button("Upgrade to Premium") { showPaywall = true }
            }
            Button("Manage Subscription") { showPaywall = true }
            Button("Restore Purchases") {
                Task { try? await container.subscription.restorePurchases() }
            }
        }
    }

    private var goalsSection: some View {
        Section("Goals") {
            Button("Edit Goals") { showGoalsSheet = true }
            LabeledContent("Recovery Target", value: "\(viewModel.profile?.recoveryTarget ?? 75)")
            LabeledContent("Daily Water", value: "\(viewModel.profile?.dailyWaterGoalML ?? 2500) ml")
            LabeledContent("Sleep Target", value: String(format: "%.1f h", viewModel.profile?.sleepHoursTarget ?? 8))
        }
    }

    private var notificationsSection: some View {
        Section("Notifications & Security") {
            Toggle("Notifications", isOn: binding(\.notificationsEnabled))
            Toggle("\(container.biometrics.biometricType) Unlock", isOn: Binding(
                get: { viewModel.profile?.faceIDEnabled ?? false },
                set: { newValue in
                    Task { await viewModel.toggleFaceID(enabled: newValue, container: container, modelContext: modelContext) }
                }
            ))
            .disabled(!container.biometrics.isAvailable)
        }
    }

    private var privacySection: some View {
        Section("Privacy & Data") {
            LabeledContent("HealthKit", value: viewModel.healthKitAuthorized ? "Connected" : "Not Connected")
            Button("Export CSV") {
                viewModel.exportData(format: .csv, modelContext: modelContext, container: container)
            }
            if container.currentTier != .free {
                Button("Export PDF Report") {
                    viewModel.exportData(format: .pdf, modelContext: modelContext, container: container)
                }
            }
            Button("Delete Account", role: .destructive) {
                viewModel.showDeleteConfirmation = true
            }
        }
    }

    private var aiSection: some View {
        Section("Peak Coach AI") {
            Toggle("Use xAI Grok API", isOn: binding(\.useGrokAPI))
            SecureField("xAI API Key", text: $grokAPIKey)
                .onSubmit { saveAPIKey() }
            Text("API key stored securely in Keychain. Optional — on-device fallback always available.")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link("Privacy Policy", destination: URL(string: PeakConstants.URLs.privacyPolicy)!)
            Link("Terms of Service", destination: URL(string: PeakConstants.URLs.termsOfService)!)
            Link("Support", destination: URL(string: PeakConstants.URLs.support)!)
            Link("Roadmap", destination: URL(string: PeakConstants.URLs.roadmap)!)
            LabeledContent("Version", value: "1.0.0")
            DisclaimerBanner(compact: true)
        }
    }

    private var goalsSheet: some View {
        GoalsEditSheet(profile: viewModel.profile, viewModel: viewModel, modelContext: modelContext)
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.profile?[keyPath: keyPath] ?? false },
            set: { newValue in
                viewModel.profile?[keyPath: keyPath] = newValue
                try? modelContext.save()
                if let profile = viewModel.profile {
                    container.notifications.configure(profile: profile)
                }
            }
        )
    }

    private func saveAPIKey() {
        guard !grokAPIKey.isEmpty else { return }
        try? container.keychain.save(grokAPIKey, for: .grokAPIKey)
        grokAPIKey = ""
        PeakHaptics.success()
    }
}

struct GoalsEditSheet: View {
    let profile: UserProfile?
    let viewModel: ProfileViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recovery = 75
    @State private var water = 2500
    @State private var sleep = 8.0

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Recovery Target: \(recovery)", value: $recovery, in: 50...95)
                Stepper("Water: \(water) ml", value: $water, in: 1500...4000, step: 250)
                Slider(value: $sleep, in: 6...10, step: 0.5) {
                    Text("Sleep: \(sleep.formattedOneDecimal)h")
                }
            }
            .navigationTitle("Edit Goals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateGoals(recovery: recovery, water: water, sleep: sleep, modelContext: modelContext)
                        dismiss()
                    }
                }
            }
            .onAppear {
                recovery = profile?.recoveryTarget ?? 75
                water = profile?.dailyWaterGoalML ?? 2500
                sleep = profile?.sleepHoursTarget ?? 8
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}