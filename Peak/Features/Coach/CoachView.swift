import SwiftData
import SwiftUI

struct CoachView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var viewModel = CoachViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                usageBar
                DisclaimerBanner(compact: true)
                    .padding(.horizontal, PeakTheme.Spacing.md)
                    .padding(.vertical, PeakTheme.Spacing.xs)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: PeakTheme.Spacing.md) {
                            ForEach(viewModel.messages, id: \.id) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }

                            if viewModel.isTyping {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, PeakTheme.Spacing.md)
                        .peakContentInsets()
                    }
                    .peakDismissKeyboardOnSwipe()
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                VStack(spacing: 0) {
                    suggestionChips
                    inputBar
                }
                .padding(.bottom, 88)
            }
            .peakScreenBackground()
            .navigationTitle("Peak Coach")
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
        .onAppear {
            viewModel.load(modelContext: modelContext, ai: container.ai, tier: container.currentTier)
        }
    }

    private var usageBar: some View {
        HStack {
            Label(coachEngineLabel, systemImage: coachEngineIcon)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(coachUsesOpenAI ? PeakTheme.ultraviolet : PeakTheme.accent)
            Text("· \(viewModel.usageCount)/\(viewModel.usageLimit)")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            Spacer()
            if viewModel.usageCount >= viewModel.usageLimit {
                Text("Upgrade for more")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.coral)
            }
        }
        .padding(.horizontal, PeakTheme.Spacing.md)
        .padding(.top, PeakTheme.Spacing.xs)
    }

    private var coachUsesOpenAI: Bool {
        (profiles.first?.useOpenAIAPI ?? false) && container.keychain.read(for: .openAIAPIKey) != nil
    }

    private var coachEngineLabel: String { coachUsesOpenAI ? "OpenAI Coach" : "On-device Coach" }
    private var coachEngineIcon: String { coachUsesOpenAI ? "sparkles" : "iphone.gen3" }

    private func messageBubble(_ message: CoachMessage) -> some View {
        let isUser = message.coachRole == .user

        return HStack {
            if isUser { Spacer(minLength: 48) }

            Text(LocalizedStringKey(message.content))
                .font(PeakTheme.Typography.body)
                .foregroundStyle(isUser ? .white : PeakTheme.textPrimary)
                .padding(PeakTheme.Spacing.md)
                .background(
                    isUser
                        ? AnyShapeStyle(PeakTheme.accentGradient)
                        : AnyShapeStyle(.thinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.lg))

            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityLabel("\(isUser ? "You" : "Coach"): \(message.content)")
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(PeakTheme.textSecondary)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                }
            }
            .padding(PeakTheme.Spacing.md)
            .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.ultraviolet.opacity(0.035))
            Spacer()
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PeakTheme.Spacing.xs) {
                ForEach(viewModel.suggestionChips, id: \.self) { chip in
                    Button(chip) {
                        Task {
                            await viewModel.sendChip(chip, modelContext: modelContext, ai: container.ai, tier: container.currentTier)
                        }
                    }
                    .font(PeakTheme.Typography.caption)
                    .padding(.horizontal, PeakTheme.Spacing.sm)
                    .padding(.vertical, PeakTheme.Spacing.xs)
                    .glassCapsule(tint: PeakTheme.teal.opacity(0.12), interactive: true)
                    .foregroundStyle(PeakTheme.teal)
                }
            }
            .padding(.horizontal, PeakTheme.Spacing.md)
        }
        .padding(.vertical, PeakTheme.Spacing.xs)
    }

    private var inputBar: some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            TextField("Ask Peak Coach...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(PeakTheme.Spacing.sm)
                .glassCard(cornerRadius: PeakTheme.Radius.md, interactive: true)

            Button {
                Task {
                    await viewModel.send(modelContext: modelContext, ai: container.ai, tier: container.currentTier)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.inputText.trimmed.isEmpty ? PeakTheme.textSecondary : PeakTheme.coral)
            }
            .disabled(viewModel.inputText.trimmed.isEmpty || viewModel.isTyping)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.lg)
        .padding(.horizontal, PeakTheme.Spacing.sm)
        .padding(.bottom, PeakTheme.Spacing.xs)
    }
}

#Preview {
    CoachView()
        .peakPreviewShell()
}
