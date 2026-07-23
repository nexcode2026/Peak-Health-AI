import SwiftData
import SwiftUI

struct TrackView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TrackViewModel()
    @State private var moodRating = 3
    @State private var energyLevel = 3
    @State private var moodNote = ""
    @State private var showMoodSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker

                ScrollView {
                    switch viewModel.selectedSection {
                    case .habits: habitsSection
                    case .hydration: hydrationSection
                    case .mood: moodSection
                    }
                }
            }
            .background(PeakTheme.background)
            .navigationTitle("Track")
            .sheet(isPresented: $showMoodSheet) { moodSheet }
        }
        .onAppear { viewModel.load(modelContext: modelContext) }
    }

    private var sectionPicker: some View {
        Picker("Section", selection: $viewModel.selectedSection) {
            ForEach(TrackViewModel.TrackSection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(PeakTheme.Spacing.md)
    }

    private var habitsSection: some View {
        LazyVStack(spacing: PeakTheme.Spacing.sm) {
            if viewModel.habits.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Habits Yet",
                    message: "Add micro-habits in Settings to start building streaks."
                )
            } else {
                ForEach(viewModel.habits, id: \.id) { habit in
                    habitRow(habit)
                }
            }
        }
        .padding(PeakTheme.Spacing.md)
    }

    private func habitRow(_ habit: HabitDefinition) -> some View {
        let completed = viewModel.todayHabitLogs[habit.id] ?? false

        return Button {
            viewModel.toggleHabit(habit, modelContext: modelContext)
        } label: {
            HStack(spacing: PeakTheme.Spacing.md) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(completed ? PeakTheme.success : PeakTheme.textSecondary)

                Image(systemName: habit.icon)
                    .foregroundStyle(Color(hex: habit.colorHex))

                Text(habit.name)
                    .font(PeakTheme.Typography.headline)
                    .foregroundStyle(PeakTheme.textPrimary)

                Spacer()
            }
            .padding(PeakTheme.Spacing.md)
            .background(PeakTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
        }
        .accessibilityLabel("\(habit.name), \(completed ? "completed" : "not completed")")
    }

    private var hydrationSection: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            PeakCard {
                VStack(spacing: PeakTheme.Spacing.md) {
                    Text("\(viewModel.hydrationML) ml")
                        .font(PeakTheme.Typography.largeTitle)
                        .foregroundStyle(PeakTheme.teal)

                    Text("of \(viewModel.hydrationGoal) ml goal")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)

                    ProgressView(value: Double(viewModel.hydrationML), total: Double(viewModel.hydrationGoal))
                        .tint(PeakTheme.teal)
                }
            }

            Button {
                viewModel.addHydration(modelContext: modelContext)
            } label: {
                Label("+1 Glass (\(PeakConstants.Defaults.habitGlassML)ml)", systemImage: "drop.fill")
            }
            .buttonStyle(PeakPrimaryButtonStyle())

            Button {
                viewModel.addHydration(ml: 500, modelContext: modelContext)
            } label: {
                Text("+500ml")
                    .font(PeakTheme.Typography.headline)
                    .foregroundStyle(PeakTheme.teal)
            }
        }
        .padding(PeakTheme.Spacing.md)
    }

    private var moodSection: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            if let today = viewModel.todayMood {
                PeakCard {
                    HStack {
                        Text(today.moodEmoji).font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text("Today's Mood: \(today.moodRating)/5")
                                .font(PeakTheme.Typography.headline)
                            if let note = today.note {
                                Text(note)
                                    .font(PeakTheme.Typography.caption)
                                    .foregroundStyle(PeakTheme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }

            Button("Log Mood & Reflection") { showMoodSheet = true }
                .buttonStyle(PeakPrimaryButtonStyle())

            if !viewModel.recentMoods.isEmpty {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                    Text("History")
                        .font(PeakTheme.Typography.headline)

                    ForEach(viewModel.recentMoods.prefix(7), id: \.id) { mood in
                        HStack {
                            Text(mood.moodEmoji)
                            Text(mood.date.formattedShort)
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                            Spacer()
                            Text("\(mood.moodRating)/5")
                                .font(PeakTheme.Typography.caption)
                        }
                        .padding(.vertical, PeakTheme.Spacing.xs)
                    }
                }
            }
        }
        .padding(PeakTheme.Spacing.md)
    }

    private var moodSheet: some View {
        NavigationStack {
            VStack(spacing: PeakTheme.Spacing.lg) {
                Text("How are you feeling?")
                    .font(PeakTheme.Typography.title)

                MoodPicker(rating: $moodRating)

                VStack(alignment: .leading) {
                    Text("Energy Level")
                        .font(PeakTheme.Typography.caption)
                    Slider(value: Binding(get: { Double(energyLevel) }, set: { energyLevel = Int($0) }), in: 1...5, step: 1)
                        .tint(PeakTheme.coral)
                }

                TextField("Optional note...", text: $moodNote, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(PeakTheme.Spacing.md)
                    .background(PeakTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))

                Spacer()
            }
            .padding(PeakTheme.Spacing.lg)
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMoodSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.logMood(
                            rating: moodRating,
                            energy: energyLevel,
                            note: moodNote.isEmpty ? nil : moodNote,
                            tags: [],
                            modelContext: modelContext
                        )
                        showMoodSheet = false
                        moodNote = ""
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    TrackView()
        .modelContainer(SampleDataGenerator.previewContainer())
        .environment(\.appContainer, AppContainer())
}