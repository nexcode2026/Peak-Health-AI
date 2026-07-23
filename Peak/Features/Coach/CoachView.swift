import SwiftData
import SwiftUI

struct CoachView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var viewModel = CoachViewModel()
    @State private var showSidebar = false
    @State private var renamingConversation: CoachConversation?
    @State private var renameText = ""
    @AppStorage("peak.coach.memoryEnabled") private var memoryEnabled = true
    @AppStorage("peak.coach.historyDays") private var historyDays = 7
    @AppStorage("peak.coach.tone") private var toneRawValue = CoachTone.supportive.rawValue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                coachContextHeader
                DisclaimerBanner(compact: true)
                    .padding(.horizontal, PeakTheme.Spacing.md)
                    .padding(.bottom, PeakTheme.Spacing.xs)

                conversationStream

                VStack(spacing: 0) {
                    suggestionChips
                    inputBar
                }
                .padding(.bottom, 76)
            }
            .peakScreenBackground()
            .navigationTitle(viewModel.conversation?.title ?? "Peak Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel("Open chats and Coach settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createConversation(modelContext: modelContext)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Coach chat")
                }
            }
            .alert("Rename Chat", isPresented: Binding(
                get: { renamingConversation != nil },
                set: { if !$0 { renamingConversation = nil } }
            )) {
                TextField("Chat name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingConversation = nil }
                Button("Save") {
                    if let conversation = renamingConversation {
                        viewModel.renameConversation(conversation, title: renameText, modelContext: modelContext)
                    }
                    renamingConversation = nil
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .sheet(isPresented: $showSidebar) {
                coachSidebar
            }
            .sheet(item: $viewModel.pendingLogAction) { action in
                quickLogSheet(action)
            }
        }
        .onAppear {
            configureCoach()
            viewModel.load(modelContext: modelContext, ai: container.ai, tier: container.currentTier)
        }
        .onChange(of: memoryEnabled) { _, _ in refreshCoachConfiguration() }
        .onChange(of: historyDays) { _, _ in refreshCoachConfiguration() }
        .onChange(of: toneRawValue) { _, _ in refreshCoachConfiguration() }
        .onChange(of: viewModel.selectedDate) { _, _ in
            viewModel.refreshSuggestions(modelContext: modelContext, ai: container.ai)
        }
    }

    private var conversationStream: some View {
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
                .padding(.top, PeakTheme.Spacing.sm)
                .peakContentInsets()
            }
            .peakDismissKeyboardOnSwipe()
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var coachContextHeader: some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            HStack(spacing: PeakTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(PeakTheme.ultraviolet.opacity(0.16))
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(PeakTheme.ultraviolet)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(personalizedCoachTitle)
                        .font(PeakTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(coachUsesOpenAI ? PeakTheme.mint : PeakTheme.accent)
                            .frame(width: 6, height: 6)
                        Text(coachEngineLabel)
                        Text("·")
                        Text("\(historyDays)-day context")
                    }
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                }
                Spacer()
                Text("\(viewModel.usageCount)/\(viewModel.usageLimit)")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .glassCapsule(tint: PeakTheme.ultraviolet.opacity(0.08))
            }

            HStack {
                Label(memoryEnabled ? "Memory on" : "Memory off", systemImage: memoryEnabled ? "brain.fill" : "brain")
                    .foregroundStyle(memoryEnabled ? PeakTheme.mint : PeakTheme.textSecondary)
                Spacer()
                DayNavigator(selectedDate: $viewModel.selectedDate, compact: true)
            }
            .font(PeakTheme.Typography.micro)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.ultraviolet.opacity(0.055))
        .padding(.horizontal, PeakTheme.Spacing.md)
        .padding(.top, PeakTheme.Spacing.xs)
    }

    private var personalizedCoachTitle: String {
        let name = profiles.first?.displayName.split(separator: " ").first.map(String.init)
        return name.map { "\($0)’s Peak Coach" } ?? "Your Peak Coach"
    }

    private var coachUsesOpenAI: Bool {
        (profiles.first?.useOpenAIAPI ?? false) && container.keychain.read(for: .openAIAPIKey) != nil
    }

    private var coachEngineLabel: String {
        coachUsesOpenAI ? "OpenAI connected" : "Private on-device mode"
    }

    private func messageBubble(_ message: CoachMessage) -> some View {
        let isUser = message.coachRole == .user

        return HStack(alignment: .bottom, spacing: PeakTheme.Spacing.xs) {
            if isUser { Spacer(minLength: 42) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(PeakTheme.ultraviolet)
                    .frame(width: 26, height: 26)
                    .glassCapsule(tint: PeakTheme.ultraviolet.opacity(0.12))
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(LocalizedStringKey(message.content))
                    .font(PeakTheme.Typography.body)
                    .foregroundStyle(isUser ? .white : PeakTheme.textPrimary)
                    .padding(PeakTheme.Spacing.md)
                    .background(
                        isUser
                            ? AnyShapeStyle(PeakTheme.accentGradient)
                            : AnyShapeStyle(.thinMaterial)
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: PeakTheme.Radius.lg,
                            bottomLeadingRadius: isUser ? PeakTheme.Radius.lg : 5,
                            bottomTrailingRadius: isUser ? 5 : PeakTheme.Radius.lg,
                            topTrailingRadius: PeakTheme.Radius.lg
                        )
                    )
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundStyle(PeakTheme.textSecondary)
            }

            if !isUser { Spacer(minLength: 42) }
        }
        .accessibilityLabel("\(isUser ? "You" : "Coach"): \(message.content)")
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .foregroundStyle(PeakTheme.ultraviolet)
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(PeakTheme.textSecondary)
                        .frame(width: 7, height: 7)
                        .opacity(0.6)
                }
            }
            .padding(PeakTheme.Spacing.md)
            .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.ultraviolet.opacity(0.04))
            Spacer()
        }
        .accessibilityLabel("Peak Coach is responding")
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PeakTheme.Spacing.xs) {
                quickLogChip("Log water", icon: "drop.fill", action: .water)
                quickLogChip("Log meal", icon: "fork.knife", action: .meal)
                ForEach(viewModel.suggestionChips, id: \.self) { chip in
                    Button(chip) {
                        Task {
                            await viewModel.sendChip(
                                chip,
                                modelContext: modelContext,
                                ai: container.ai,
                                tier: container.currentTier
                            )
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

    private func quickLogChip(
        _ title: String,
        icon: String,
        action: CoachViewModel.QuickLogAction
    ) -> some View {
        Button {
            viewModel.pendingLogAction = action
        } label: {
            Label(title, systemImage: icon)
        }
        .font(PeakTheme.Typography.caption)
        .padding(.horizontal, PeakTheme.Spacing.sm)
        .padding(.vertical, PeakTheme.Spacing.xs)
        .glassCapsule(tint: PeakTheme.coral.opacity(0.12), interactive: true)
        .foregroundStyle(PeakTheme.coral)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: PeakTheme.Spacing.sm) {
            TextField("Ask about your data or log something…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(PeakTheme.Spacing.sm)
                .glassCard(cornerRadius: PeakTheme.Radius.md, interactive: true)

            Button {
                Task {
                    await viewModel.send(
                        modelContext: modelContext,
                        ai: container.ai,
                        tier: container.currentTier
                    )
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        viewModel.inputText.trimmed.isEmpty
                            ? AnyShapeStyle(PeakTheme.textSecondary.opacity(0.35))
                            : AnyShapeStyle(PeakTheme.accentGradient),
                        in: Circle()
                    )
            }
            .disabled(viewModel.inputText.trimmed.isEmpty || viewModel.isTyping)
        }
        .padding(PeakTheme.Spacing.sm)
        .glassCard(cornerRadius: PeakTheme.Radius.lg)
        .padding(.horizontal, PeakTheme.Spacing.sm)
        .padding(.bottom, PeakTheme.Spacing.xs)
    }

    private var coachSidebar: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        viewModel.createConversation(modelContext: modelContext)
                        showSidebar = false
                    } label: {
                        Label("New conversation", systemImage: "square.and.pencil")
                            .foregroundStyle(PeakTheme.accent)
                    }
                }

                Section("Chats") {
                    ForEach(viewModel.conversations, id: \.id) { conversation in
                        Button {
                            viewModel.selectConversation(conversation)
                            showSidebar = false
                        } label: {
                            HStack(spacing: PeakTheme.Spacing.sm) {
                                Image(systemName: conversation.id == viewModel.conversation?.id
                                    ? "bubble.left.and.bubble.right.fill"
                                    : "bubble.left.and.bubble.right")
                                    .foregroundStyle(conversation.id == viewModel.conversation?.id
                                        ? PeakTheme.ultraviolet
                                        : PeakTheme.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title)
                                        .foregroundStyle(PeakTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(PeakTheme.Typography.micro)
                                        .foregroundStyle(PeakTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameText = conversation.title
                                renamingConversation = conversation
                                showSidebar = false
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                viewModel.deleteConversation(conversation, modelContext: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Section("Coach settings") {
                    Toggle(isOn: $memoryEnabled) {
                        Label("Conversation memory", systemImage: "brain.fill")
                    }
                    Picker(selection: $historyDays) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    } label: {
                        Label("Live data window", systemImage: "calendar")
                    }
                    Picker(selection: $toneRawValue) {
                        ForEach(CoachTone.allCases) { tone in
                            Text(tone.title).tag(tone.rawValue)
                        }
                    } label: {
                        Label("Coaching style", systemImage: "slider.horizontal.3")
                    }
                }

                Section("AI & privacy") {
                    Label(
                        coachUsesOpenAI ? "OpenAI connected" : "On-device fallback",
                        systemImage: coachUsesOpenAI ? "checkmark.shield.fill" : "iphone.gen3"
                    )
                    Text(memoryEnabled
                        ? "Peak may include themes from your other chats with the selected health-data window. OpenAI is used only when enabled and a Keychain key is present."
                        : "Cross-chat memory is off. Peak sends only this chat and the selected health-data window when OpenAI is enabled.")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .peakScreenBackground()
            .navigationTitle("Peak Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSidebar = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func quickLogSheet(_ action: CoachViewModel.QuickLogAction) -> some View {
        switch action {
        case .water:
            LogWaterSheet(date: viewModel.selectedDate)
        case .meal:
            LogFoodSheet(date: viewModel.selectedDate)
        case .workout:
            LogWorkoutSheet(date: viewModel.selectedDate)
        case .mood:
            LogMoodSheet { rating, energy, note, tags in
                saveMood(rating: rating, energy: energy, note: note, tags: tags)
            }
        }
    }

    private func saveMood(rating: Int, energy: Int, note: String?, tags: [String]) {
        let day = viewModel.selectedDate.startOfDay
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let existing = try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= day && $0.date < nextDay }
        )).first
        if let existing {
            existing.moodRating = rating.clamped(to: 1...5)
            existing.energyLevel = energy.clamped(to: 1...5)
            existing.note = note
            existing.tags = tags
            existing.updatedAt = .now
        } else {
            modelContext.insert(MoodReflection(
                moodRating: rating,
                energyLevel: energy,
                note: note,
                tags: tags,
                date: day
            ))
        }
        try? modelContext.save()
        PeakHaptics.success()
        viewModel.refreshSuggestions(modelContext: modelContext, ai: container.ai)
    }

    private func configureCoach() {
        viewModel.configure(
            memoryEnabled: memoryEnabled,
            historyDays: historyDays,
            tone: CoachTone(rawValue: toneRawValue) ?? .supportive
        )
    }

    private func refreshCoachConfiguration() {
        configureCoach()
        viewModel.refreshSuggestions(modelContext: modelContext, ai: container.ai)
    }
}

#Preview {
    CoachView()
        .peakPreviewShell()
}
