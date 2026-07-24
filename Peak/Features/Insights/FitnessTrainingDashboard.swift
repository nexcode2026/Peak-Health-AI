import Charts
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FitnessTrainingViewModel {
    var workouts: [WorkoutLog] = []

    func load(modelContext: ModelContext, days: Int = 30) {
        let start = Date().daysAgo(max(1, days)).startOfDay
        workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
    }

    var strengthSessions: [WorkoutLog] {
        workouts.filter { $0.type == .strength }
    }

    var cardioSessions: [WorkoutLog] {
        workouts.filter { [.running, .walking, .cycling, .swimming, .hiit].contains($0.type) }
    }

    var activeDays: Int {
        Set(workouts.map { $0.date.startOfDay }).count
    }

    var totalMinutes: Double {
        workouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalCalories: Double {
        workouts.reduce(0) { $0 + $1.caloriesBurned }
    }

    var trainingLoad: Int {
        Int(workouts.reduce(0) {
            $0 + $1.durationMinutes * $1.workoutIntensity.multiplier
        }.rounded())
    }

    var dailyLoad: [FitnessDayLoad] {
        let grouped = Dictionary(grouping: workouts) { $0.date.startOfDay }
        return (0..<30).reversed().map { offset in
            let day = Date().daysAgo(offset).startOfDay
            let sessions = grouped[day] ?? []
            return FitnessDayLoad(
                date: day,
                load: sessions.reduce(0) {
                    $0 + $1.durationMinutes * $1.workoutIntensity.multiplier
                },
                minutes: sessions.reduce(0) { $0 + $1.durationMinutes }
            )
        }
    }
}

struct FitnessDayLoad: Identifiable {
    var id: Date { date }
    let date: Date
    let load: Double
    let minutes: Double
}

struct FitnessTrainingDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FitnessTrainingViewModel()
    @State private var showLogTraining = false
    @State private var showTemplateManager = false
    @State private var selectedTemplate: TrainingTemplate?
    @State private var editingWorkout: WorkoutLog?
    @AppStorage(TrainingTemplateStore.key) private var templateData = Data()

    private var templates: [TrainingTemplate] {
        TrainingTemplateStore.load(from: templateData)
    }

    var body: some View {
        VStack(spacing: PeakTheme.Spacing.lg) {
            trainingHero
            categorySummary
            loadChart
            templateSection
            recentSessions
        }
        .onAppear { reload() }
        .sheet(isPresented: $showLogTraining, onDismiss: reload) {
            LogWorkoutSheet()
        }
        .sheet(item: $selectedTemplate, onDismiss: reload) { template in
            LogWorkoutSheet(template: template)
        }
        .sheet(item: $editingWorkout, onDismiss: reload) { workout in
            LogWorkoutSheet(date: workout.date, workout: workout)
        }
        .sheet(isPresented: $showTemplateManager) {
            TrainingTemplateManagerView(data: $templateData)
        }
    }

    private var trainingHero: some View {
        PeakCard(padding: PeakTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("30-Day Fitness", systemImage: "figure.strengthtraining.traditional")
                            .font(PeakTheme.Typography.headline)
                            .foregroundStyle(PeakTheme.coral)
                        Text("\(viewModel.trainingLoad)")
                            .font(PeakTheme.Typography.heroScore)
                        Text("training load · \(viewModel.activeDays) active days")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                    ProgressRing(
                        progress: min(1, Double(viewModel.activeDays) / 12),
                        label: "Active",
                        value: "\(viewModel.activeDays)d",
                        color: PeakTheme.coral,
                        size: 76
                    )
                }

                HStack(spacing: PeakTheme.Spacing.sm) {
                    Button { showLogTraining = true } label: {
                        Label("Log Training", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PeakTheme.coral)

                    Button { showTemplateManager = true } label: {
                        Label("Plans", systemImage: "square.stack.3d.up.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PeakTheme.lavender)
                }
            }
        }
    }

    private var categorySummary: some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            categoryCard(
                "Strength",
                icon: "dumbbell.fill",
                sessions: viewModel.strengthSessions,
                color: PeakTheme.lavender
            )
            categoryCard(
                "Cardio",
                icon: "heart.circle.fill",
                sessions: viewModel.cardioSessions,
                color: PeakTheme.coral
            )
        }
    }

    private func categoryCard(
        _ title: String,
        icon: String,
        sessions: [WorkoutLog],
        color: Color
    ) -> some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                Label(title, systemImage: icon)
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(color)
                Text("\(sessions.count) sessions")
                    .font(PeakTheme.Typography.title)
                Text("\(Int(sessions.reduce(0) { $0 + $1.durationMinutes })) min")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loadChart: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity & Strain")
                            .font(PeakTheme.Typography.headline)
                        Text("\(Int(viewModel.totalMinutes)) min · \(Int(viewModel.totalCalories)) kcal")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                    Label("30 days", systemImage: "calendar")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }

                Chart(viewModel.dailyLoad) { sample in
                    BarMark(
                        x: .value("Day", sample.date),
                        y: .value("Load", sample.load)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PeakTheme.coral, PeakTheme.lavender],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 160)

                Text("Training load combines session duration and logged intensity. It is a planning estimate, not a medical measurement.")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(
                title: "Training Templates",
                icon: "square.stack.3d.up.fill",
                actionTitle: "Manage"
            ) { showTemplateManager = true }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PeakTheme.Spacing.sm) {
                    ForEach(templates) { template in
                        Button { selectedTemplate = template } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: template.workoutType.icon)
                                    .foregroundStyle(Color(hex: template.workoutType.color))
                                Text(template.name)
                                    .font(PeakTheme.Typography.caption)
                                    .foregroundStyle(PeakTheme.textPrimary)
                                    .lineLimit(2)
                                Text("\(template.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min · \(template.intensity.displayName)")
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.textSecondary)
                            }
                            .frame(width: 150, height: 100, alignment: .topLeading)
                            .padding(PeakTheme.Spacing.md)
                            .glassCard(
                                cornerRadius: PeakTheme.Radius.md,
                                tint: Color(hex: template.workoutType.color).opacity(0.05),
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Recent Training", icon: "clock.arrow.circlepath")
            if viewModel.workouts.isEmpty {
                EmptyStateView(
                    icon: "figure.strengthtraining.traditional",
                    title: "Build your fitness history",
                    message: "Log training or sync workouts from Apple Health."
                )
            } else {
                ForEach(viewModel.workouts.prefix(8), id: \.id) { workout in
                    Button { editingWorkout = workout } label: {
                        HStack(spacing: PeakTheme.Spacing.md) {
                            Image(systemName: workout.type.icon)
                                .foregroundStyle(Color(hex: workout.type.color))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(PeakTheme.Typography.headline)
                                    .foregroundStyle(PeakTheme.textPrimary)
                                Text("\(workout.date.formatted(date: .abbreviated, time: .shortened)) · \(workout.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min · \(workout.workoutIntensity.displayName)")
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        .padding(PeakTheme.Spacing.md)
                        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: Color(hex: workout.type.color).opacity(0.035))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editingWorkout = workout } label: {
                            Label("Edit Training", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(workout)
                            try? modelContext.save()
                            reload()
                        } label: {
                            Label("Delete Training", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func reload() {
        viewModel.load(modelContext: modelContext)
        if templateData.isEmpty {
            templateData = TrainingTemplateStore.encode(TrainingTemplate.starter)
        }
    }
}

struct TrainingTemplateManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var data: Data
    @State private var templates: [TrainingTemplate] = []
    @State private var editingTemplate: TrainingTemplate?
    @State private var showGenerator = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { editingTemplate = TrainingTemplate(
                        name: "New Training Plan",
                        workoutType: .strength,
                        durationMinutes: 45,
                        intensity: .moderate,
                        exerciseDetails: "",
                        note: ""
                    ) } label: {
                        Label("Create Template", systemImage: "plus.circle.fill")
                    }
                    Button { showGenerator = true } label: {
                        Label("Generate Starter Plans", systemImage: "wand.and.stars")
                    }
                }

                Section("Your Templates") {
                    ForEach(templates) { template in
                        Button { editingTemplate = template } label: {
                            HStack {
                                Image(systemName: template.workoutType.icon)
                                    .foregroundStyle(Color(hex: template.workoutType.color))
                                VStack(alignment: .leading) {
                                    Text(template.name).foregroundStyle(PeakTheme.textPrimary)
                                    Text("\(template.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min · \(template.intensity.displayName)")
                                        .font(PeakTheme.Typography.micro)
                                        .foregroundStyle(PeakTheme.textSecondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        templates.remove(atOffsets: offsets)
                        persist()
                    }
                }
            }
            .navigationTitle("Training Plans")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { templates = TrainingTemplateStore.load(from: data) }
            .sheet(item: $editingTemplate) { template in
                TrainingTemplateEditorSheet(template: template) { updated in
                    if let index = templates.firstIndex(where: { $0.id == updated.id }) {
                        templates[index] = updated
                    } else {
                        templates.append(updated)
                    }
                    persist()
                }
            }
            .sheet(isPresented: $showGenerator) {
                TrainingPlanGeneratorSheet { generated in
                    let existing = Set(templates.map(\.name))
                    templates.append(contentsOf: generated.filter { !existing.contains($0.name) })
                    persist()
                }
            }
        }
    }

    private func persist() {
        data = TrainingTemplateStore.encode(templates)
    }
}

struct TrainingTemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var template: TrainingTemplate
    let onSave: (TrainingTemplate) -> Void

    init(template: TrainingTemplate, onSave: @escaping (TrainingTemplate) -> Void) {
        _template = State(initialValue: template)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Template name", text: $template.name)
                Picker("Training type", selection: $template.workoutType) {
                    ForEach(WorkoutType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Duration · \(template.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min")
                    Slider(value: $template.durationMinutes, in: 5...240, step: 0.5)
                }
                Picker("Intensity", selection: $template.intensity) {
                    ForEach(WorkoutIntensity.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                TextField(
                    "Exercises, sets, reps, or intervals",
                    text: $template.exerciseDetails,
                    axis: .vertical
                )
                .lineLimit(5...12)
                TextField("Coaching notes", text: $template.note, axis: .vertical)
                    .lineLimit(2...5)
            }
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(template)
                        dismiss()
                    }
                    .disabled(template.name.trimmed.isEmpty)
                }
            }
        }
    }
}

struct TrainingPlanGeneratorSheet: View {
    enum Focus: String, CaseIterable, Identifiable {
        case balanced = "Balanced"
        case strength = "Strength"
        case cardio = "Cardio"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var focus: Focus = .balanced
    let onGenerate: ([TrainingTemplate]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Focus", selection: $focus) {
                        ForEach(Focus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("What Peak creates") {
                    Label("Three editable weekly templates", systemImage: "calendar.badge.plus")
                    Label("Exercise, interval, and recovery structure", systemImage: "list.bullet.clipboard")
                    Label("Plans remain fully editable before logging", systemImage: "pencil")
                }
            }
            .navigationTitle("Generate Training")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        onGenerate(generated)
                        dismiss()
                    }
                }
            }
        }
    }

    private var generated: [TrainingTemplate] {
        switch focus {
        case .strength:
            return [
                template("Upper Body Strength", .strength, 50, "Bench press · 4 × 6\nRow · 4 × 8\nOverhead press · 3 × 8\nLat pulldown · 3 × 10\nCarry · 3 × 40 m"),
                template("Lower Body Strength", .strength, 55, "Squat · 4 × 6\nRomanian deadlift · 3 × 8\nSplit squat · 3 × 10/side\nCalf raise · 3 × 12\nPlank · 3 sets"),
                template("Strength Recovery", .stretching, 25, "Easy walk · 10 min\nHip and shoulder mobility · 10 min\nBreathing cooldown · 5 min"),
            ]
        case .cardio:
            return [
                template("Aerobic Base", .running, 40, "5 min warm-up\n30 min conversational pace\n5 min cool-down", intensity: .low),
                template("Tempo Intervals", .running, 35, "10 min easy\n4 × 4 min comfortably hard with 2 min easy\n5 min cool-down", intensity: .high),
                template("Cardio Recovery", .walking, 30, "Easy outdoor walk at a relaxed, conversational pace.", intensity: .low),
            ]
        case .balanced:
            return [
                template("Full Body A", .strength, 45, "Squat · 3 × 8\nBench press · 3 × 8\nRow · 3 × 10\nPlank · 3 sets"),
                template("Cardio Base", .cycling, 40, "5 min easy\n30 min conversational pace\n5 min cool-down", intensity: .low),
                template("Full Body B", .strength, 45, "Deadlift · 3 × 6\nOverhead press · 3 × 8\nSplit squat · 3 × 10/side\nPulldown · 3 × 10"),
            ]
        }
    }

    private func template(
        _ name: String,
        _ type: WorkoutType,
        _ minutes: Double,
        _ details: String,
        intensity: WorkoutIntensity = .moderate
    ) -> TrainingTemplate {
        TrainingTemplate(
            name: name,
            workoutType: type,
            durationMinutes: minutes,
            intensity: intensity,
            exerciseDetails: details,
            note: "Adjust volume and intensity to your recovery and experience."
        )
    }
}
