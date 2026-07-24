private struct TrackChipStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PeakTheme.Typography.caption)
            .padding(.horizontal, PeakTheme.Spacing.md)
            .padding(.vertical, PeakTheme.Spacing.xs)
            .background(backgroundColor(configuration: configuration))
            .foregroundStyle(foregroundColor(configuration: configuration))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor(configuration: configuration), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if isSelected { return PeakTheme.accent.opacity(0.15) }
        return PeakTheme.surface
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        if isSelected { return PeakTheme.accent }
        return PeakTheme.textPrimary
    }

    private func borderColor(configuration: Configuration) -> Color {
        if isSelected { return PeakTheme.accent.opacity(0.4) }
        return PeakTheme.surfaceElevated
    }
}

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
    @State private var showCreateHabit = false
    @State private var showLogFood = false
    @State private var showLogWorkout = false
    @State private var editingFood: FoodLog?
    @State private var editingWorkout: WorkoutLog?

    private var displayFormatter: UnitFormatter { UnitFormatter(system: viewModel.unitSystem) }
    @State private var showLogWater = false
    @State private var showActiveWorkout = false
    @State private var selectedDate = Date().startOfDay

    init(initialDate: Date = .now) {
        _selectedDate = State(initialValue: initialDate.startOfDay)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    DayNavigator(selectedDate: $selectedDate)
                    todaySummaryCard
                    categoryChips
                    sectionContent
                }
                .padding(.horizontal, PeakTheme.Spacing.md)
                .peakContentInsets()
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationTitle("Journal")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showMoodSheet) {
                LogMoodSheet(
                    initialRating: viewModel.todayMood?.moodRating ?? moodRating,
                    initialEnergy: viewModel.todayMood?.energyLevel ?? energyLevel,
                    initialNote: viewModel.todayMood?.note ?? moodNote,
                    initialTags: viewModel.todayMood?.tags ?? []
                ) { rating, energy, note, tags in
                    moodRating = rating
                    energyLevel = energy
                    moodNote = note ?? ""
                    viewModel.logMood(
                        rating: rating,
                        energy: energy,
                        note: note,
                        tags: tags,
                        modelContext: modelContext
                    )
                    container.evaluateAchievements(modelContext: modelContext)
                }
            }
            .sheet(isPresented: $showCreateHabit) { CreateHabitSheet().onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) } }
            .sheet(isPresented: $showLogFood) { LogFoodSheet(date: selectedDate).onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) } }
            .sheet(isPresented: $showLogWorkout) { LogWorkoutSheet(date: selectedDate).onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) } }
            .sheet(item: $editingFood) { food in
                LogFoodSheet(date: food.date, editingLog: food)
                    .onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) }
            }
            .sheet(item: $editingWorkout) { workout in
                LogWorkoutSheet(date: workout.date, workout: workout)
                    .onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) }
            }
            .sheet(isPresented: $showLogWater) { LogWaterSheet(date: selectedDate).onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) } }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                ActiveWorkoutView().onDisappear { viewModel.load(modelContext: modelContext, date: selectedDate) }
            }
        }
        .onAppear { viewModel.load(modelContext: modelContext, date: selectedDate) }
        .onChange(of: selectedDate) { _, newDate in
            viewModel.load(modelContext: modelContext, date: newDate)
            moodRating = viewModel.todayMood?.moodRating ?? 3
            energyLevel = viewModel.todayMood?.energyLevel ?? 3
            moodNote = viewModel.todayMood?.note ?? ""
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showLogWater = true } label: { Label("Log Water", systemImage: "drop.fill") }
                Button { showLogFood = true } label: { Label("Log Food", systemImage: "fork.knife") }
                if selectedDate.isToday {
                    Button { showActiveWorkout = true } label: { Label("Track Training (GPS)", systemImage: "location.fill") }
                }
                Button { showLogWorkout = true } label: { Label("Log Training", systemImage: "figure.run") }
                Button { showMoodSheet = true } label: { Label("Log Mood", systemImage: "face.smiling") }
                Button { showCreateHabit = true } label: { Label("Create Habit", systemImage: "plus.circle") }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PeakTheme.accent)
            }
        }
    }

    private var todaySummaryCard: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                Label(selectedDate.isToday ? "Today's Progress" : "Day Progress", systemImage: "chart.donut")
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)

                HStack(spacing: PeakTheme.Spacing.md) {
                    miniStat(icon: "drop.fill", value: displayFormatter.formatWaterShort(viewModel.hydrationML), unit: displayFormatter.waterUnitLabel, color: PeakTheme.teal)
                    miniStat(icon: "flame.fill", value: "\(viewModel.todayCalories)", unit: "kcal", color: PeakTheme.coral)
                    miniStat(icon: "figure.run", value: "\(viewModel.todayWorkouts.count)", unit: "sessions", color: PeakTheme.lavender)
                    miniStat(icon: "checkmark.circle", value: "\(viewModel.habitsCompletedCount)/\(viewModel.habits.count)", unit: "", color: PeakTheme.mint)
                }
            }
        }
    }

    private func miniStat(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(PeakTheme.Typography.subheadline).fontWeight(.bold)
            if !unit.isEmpty {
                Text(unit).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PeakTheme.Spacing.xs) {
                ForEach(TrackViewModel.TrackSection.allCases) { section in
                    Button {
                        viewModel.selectedSection = section
                        PeakHaptics.selection()
                    } label: {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                    .buttonStyle(TrackChipStyle(isSelected: viewModel.selectedSection == section))
                }
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch viewModel.selectedSection {
        case .habits: habitsSection
        case .water: waterSection
        case .food: foodSection
        case .workouts: workoutsSection
        case .mood: moodSection
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Micro-Habits", icon: "checkmark.seal.fill", actionTitle: "+ Create") { showCreateHabit = true }

            if viewModel.habits.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "No Habits Yet", message: "Create micro-habits to build streaks and boost your recovery score.", actionTitle: "Create Habit") { showCreateHabit = true }
            } else {
                ForEach(viewModel.habits, id: \.id) { habit in
                    habitRow(habit)
                }
            }
        }
    }

    private func habitRow(_ habit: HabitDefinition) -> some View {
        let completed = viewModel.todayHabitLogs[habit.id] ?? false
        return HStack(spacing: PeakTheme.Spacing.md) {
            Button {
                viewModel.toggleHabit(habit, modelContext: modelContext)
                container.evaluateAchievements(modelContext: modelContext)
            } label: {
                ZStack {
                    if completed {
                        PeakRiveView(animation: .habitCheck, accentColor: PeakTheme.mint)
                            .frame(width: 32, height: 32)
                    }
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(completed ? PeakTheme.mint : PeakTheme.textSecondary)
                        .opacity(PeakRiveAnimationLoader.canLoad(.habitCheck) && completed ? 0 : 1)
                }
            }
            Image(systemName: habit.icon).foregroundStyle(Color(hex: habit.colorHex)).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(PeakTheme.Typography.headline).foregroundStyle(PeakTheme.textPrimary)
                if habit.isCustom { Text("Custom").font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let streak = viewModel.habitStreaks[habit.id] ?? 0
                if streak > 0 {
                    Label("\(streak)d", systemImage: "flame.fill")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.coral)
                }
                Text("\(Int((viewModel.habitWeeklyRates[habit.id] ?? 0) * 100))% week")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: completed ? PeakTheme.mint.opacity(0.04) : nil)
        .overlay(RoundedRectangle(cornerRadius: PeakTheme.Radius.md).stroke(completed ? PeakTheme.mint.opacity(0.3) : Color.clear, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteHabit(habit, modelContext: modelContext)
            } label: {
                Label("Archive Habit", systemImage: "archivebox")
            }
        }
    }

    // MARK: - Water

    private var waterSection: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            SectionHeaderView(title: "Hydration", icon: "drop.fill", actionTitle: "Custom") { showLogWater = true }

            PeakCard {
                VStack(spacing: PeakTheme.Spacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(displayFormatter.formatWaterShort(viewModel.hydrationML))
                            .font(PeakTheme.Typography.heroScore)
                            .foregroundStyle(PeakTheme.teal)
                        Text(displayFormatter.waterUnitLabel)
                            .font(PeakTheme.Typography.title)
                            .foregroundStyle(PeakTheme.textSecondary)
                        Spacer()
                        Text("\(Int(viewModel.hydrationProgress * 100))%")
                            .font(PeakTheme.Typography.headline)
                            .foregroundStyle(PeakTheme.mint)
                    }
                    ProgressView(value: viewModel.hydrationProgress)
                        .tint(PeakTheme.teal)
                    Text(displayFormatter.formatWaterGoal(viewModel.hydrationGoal))
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)

                    HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(PeakTheme.mint)
                        Text(viewModel.hydrationPaceMessage)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                        Spacer()
                        if let latest = viewModel.hydrationLogs.first {
                            Button("Undo") {
                                viewModel.deleteHydration(latest, modelContext: modelContext)
                            }
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.coral)
                        }
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PeakTheme.Spacing.sm) {
                quickWaterButton(ml: 250, label: "Glass", icon: "drop.fill")
                quickWaterButton(ml: 500, label: "Bottle", icon: "waterbottle.fill")
                ForEach(BeverageType.allCases.prefix(4)) { bev in
                    Button {
                        logWater(ml: bev.defaultML, beverage: bev)
                    } label: {
                        Label(bev.displayName, systemImage: bev.icon)
                            .font(PeakTheme.Typography.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PeakTheme.Spacing.sm)
                            .glassCard(cornerRadius: PeakTheme.Radius.sm, tint: PeakTheme.teal.opacity(0.035), interactive: true)
                    }
                    .foregroundStyle(PeakTheme.teal)
                }
            }

            if !viewModel.hydrationLogs.isEmpty {
                SectionHeaderView(title: selectedDate.isToday ? "Today's Log" : "Day Log", icon: "clock.fill")
                ForEach(viewModel.hydrationLogs.prefix(8), id: \.id) { log in
                    HStack {
                        Image(systemName: log.beverage.icon).foregroundStyle(PeakTheme.teal)
                        Text("\(displayFormatter.formatWater(log.amountML)) · \(log.beverage.displayName)")
                            .font(PeakTheme.Typography.caption)
                        Spacer()
                        Text(log.createdAt.formattedTime).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteHydration(log, modelContext: modelContext)
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func logWater(ml: Int, beverage: BeverageType = .water) {
        viewModel.addHydration(ml: ml, beverage: beverage, modelContext: modelContext)
        container.evaluateAchievements(modelContext: modelContext)
        Task {
            try? await container.healthKit.writeHydration(ml: ml, date: selectedDate)
            await container.healthData.refresh(modelContext: modelContext)
        }
    }

    private func quickWaterButton(ml: Int, label: String, icon: String) -> some View {
        Button {
            logWater(ml: ml)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2)
                Text("+\(displayFormatter.formatWaterShort(ml))").font(PeakTheme.Typography.caption).fontWeight(.semibold)
                Text(label).font(PeakTheme.Typography.micro)
            }
            .frame(maxWidth: .infinity)
            .padding(PeakTheme.Spacing.md)
            .background(PeakTheme.teal.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
        }
        .foregroundStyle(PeakTheme.teal)
    }

    // MARK: - Food

    private var foodSection: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            SectionHeaderView(title: "Nutrition", icon: "fork.knife", actionTitle: "+ Log Meal") { showLogFood = true }

            HStack(spacing: PeakTheme.Spacing.sm) {
                MetricTile(icon: "flame.fill", label: "Calories", value: "\(viewModel.todayCalories)", unit: "/ \(viewModel.calorieGoal)", color: PeakTheme.coral)
                MetricTile(icon: "bolt.fill", label: "Protein", value: String(format: "%.0f", viewModel.todayProtein), unit: "g / \(viewModel.proteinGoal)", color: PeakTheme.gold)
            }

            PeakCard {
                HStack {
                    remainingNutrient("Calories left", value: "\(viewModel.caloriesRemaining)", unit: "kcal", color: PeakTheme.coral)
                    Divider().frame(height: 36)
                    remainingNutrient("Protein left", value: "\(viewModel.proteinRemaining)", unit: "g", color: PeakTheme.gold)
                }
            }

            if viewModel.todayFood.isEmpty {
                EmptyStateView(icon: "fork.knife", title: "No Meals Logged", message: "Track meals to understand how nutrition affects your recovery.", actionTitle: "Log Food") { showLogFood = true }
            } else {
                ForEach(viewModel.todayFood, id: \.id) { food in
                    HStack(spacing: PeakTheme.Spacing.md) {
                        Image(systemName: food.meal.icon)
                            .foregroundStyle(Color(hex: food.meal.color))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name).font(PeakTheme.Typography.headline)
                            Text("\(food.calories) kcal · P \(Int(food.proteinG))g")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        Spacer()
                        Text(food.meal.displayName)
                            .font(PeakTheme.Typography.micro)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PeakTheme.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    .padding(PeakTheme.Spacing.md)
                    .glassCard(cornerRadius: PeakTheme.Radius.md, tint: Color(hex: food.meal.color).opacity(0.035))
                    .contextMenu {
                        Button { editingFood = food } label: {
                            Label("Edit Meal", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            viewModel.deleteFood(food, modelContext: modelContext)
                        } label: {
                            Label("Delete Meal", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func remainingNutrient(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(PeakTheme.Typography.title)
                    .foregroundStyle(color)
                Text(unit)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Workouts

    private var workoutsSection: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            SectionHeaderView(title: "Training", icon: "dumbbell.fill", actionTitle: selectedDate.isToday ? "Track" : "+ Log") {
                if selectedDate.isToday { showActiveWorkout = true } else { showLogWorkout = true }
            }

            PeakCard {
                HStack {
                    VStack(alignment: .leading) {
                        Text("This Week").font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
                        Text("\(viewModel.weeklyWorkoutCount) / \(viewModel.weeklyWorkoutGoal)")
                            .font(PeakTheme.Typography.stat)
                    }
                    Spacer()
                    ProgressRing(progress: Double(viewModel.weeklyWorkoutCount) / Double(max(1, viewModel.weeklyWorkoutGoal)), label: "Goal", value: "\(viewModel.weeklyWorkoutCount)", color: PeakTheme.lavender, size: 56)
                }
                Divider()
                HStack {
                    Label("\(Int(viewModel.weeklyWorkoutMinutes)) min", systemImage: "timer")
                    Spacer()
                    Label("\(Int(viewModel.weeklyCaloriesBurned)) kcal", systemImage: "flame.fill")
                }
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.textSecondary)
            }

            if viewModel.todayWorkouts.isEmpty {
                EmptyStateView(
                    icon: "figure.run",
                    title: selectedDate.isToday ? "No Training Today" : "No Training Logged",
                    message: selectedDate.isToday ? "Log a session or sync from Apple Health." : "Add a session to complete this day's history.",
                    actionTitle: "Log Training"
                ) { showLogWorkout = true }
            } else {
                ForEach(viewModel.todayWorkouts, id: \.id) { workout in
                    HStack(spacing: PeakTheme.Spacing.md) {
                        Image(systemName: workout.type.icon)
                            .font(.title2)
                            .foregroundStyle(Color(hex: workout.type.color))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name).font(PeakTheme.Typography.headline)
                            Text("\(Int(workout.durationMinutes)) min · \(Int(workout.caloriesBurned)) kcal · \(displayFormatter.formatDistance(workout.distanceKm)) · \(workout.workoutIntensity.displayName)")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(PeakTheme.Spacing.md)
                    .glassCard(cornerRadius: PeakTheme.Radius.md, tint: Color(hex: workout.type.color).opacity(0.035))
                    .contextMenu {
                        Button { editingWorkout = workout } label: {
                            Label("Edit Training", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            viewModel.deleteWorkout(workout, modelContext: modelContext)
                        } label: {
                            Label("Delete Training", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(spacing: PeakTheme.Spacing.md) {
            SectionHeaderView(title: "Mood & Reflection", icon: "face.smiling.fill", actionTitle: "+ Log") { showMoodSheet = true }

            if let today = viewModel.todayMood {
                PeakCard {
                    HStack(spacing: PeakTheme.Spacing.md) {
                        Text(today.moodEmoji).font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mood \(today.moodRating)/5 · Energy \(today.energyLevel)/5")
                                .font(PeakTheme.Typography.headline)
                            if let note = today.note {
                                Text(note).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
                            }
                            if !today.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(today.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(PeakTheme.Typography.micro)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(PeakTheme.rose.opacity(0.1), in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }

            MoodPicker(rating: $moodRating) { _ in }

            if !viewModel.recentMoods.isEmpty {
                HStack {
                    SectionHeaderView(title: "History")
                    Spacer()
                    if let average = viewModel.sevenDayMoodAverage {
                        Text("7-day avg \(average, specifier: "%.1f")/5")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.rose)
                    }
                }
                ForEach(viewModel.recentMoods.prefix(7), id: \.id) { mood in
                    HStack {
                        Text(mood.moodEmoji).font(.title3)
                        Text(mood.date.formattedShort).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
                        Spacer()
                        Text("\(mood.moodRating)/5").font(PeakTheme.Typography.caption)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteMood(mood, modelContext: modelContext)
                        } label: {
                            Label("Delete Check-in", systemImage: "trash")
                        }
                    }
                }
            }

            Button(viewModel.todayMood == nil ? "Save Quick Check-in" : "Update Quick Check-in") {
                viewModel.logMood(rating: moodRating, energy: energyLevel, note: moodNote.isEmpty ? nil : moodNote, tags: [], modelContext: modelContext)
                moodNote = ""
            }
            .buttonStyle(PeakPrimaryButtonStyle())
            Button("Add context, energy & tags") {
                showMoodSheet = true
            }
            .font(PeakTheme.Typography.caption)
            .foregroundStyle(PeakTheme.rose)
        }
    }
}

struct LogMoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var energy: Int
    @State private var note: String
    @State private var selectedTags: Set<String>

    let onSave: (Int, Int, String?, [String]) -> Void

    private let tagOptions = [
        "Calm", "Focused", "Motivated", "Social",
        "Stressed", "Sore", "Tired", "Restless"
    ]

    init(
        initialRating: Int = 3,
        initialEnergy: Int = 3,
        initialNote: String? = nil,
        initialTags: [String] = [],
        onSave: @escaping (Int, Int, String?, [String]) -> Void
    ) {
        _rating = State(initialValue: initialRating)
        _energy = State(initialValue: initialEnergy)
        _note = State(initialValue: initialNote ?? "")
        _selectedTags = State(initialValue: Set(initialTags))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Text("How do you feel?")
                            .font(PeakTheme.Typography.headline)
                        MoodPicker(rating: $rating)
                    }

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        HStack {
                            Text("Energy")
                                .font(PeakTheme.Typography.headline)
                            Spacer()
                            Text("\(energy)/5")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.coral)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(energy) },
                                set: { energy = Int($0) }
                            ),
                            in: 1...5,
                            step: 1
                        )
                        .tint(PeakTheme.coral)
                    }

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Text("What influenced today?")
                            .font(PeakTheme.Typography.headline)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 88), spacing: PeakTheme.Spacing.xs)],
                            alignment: .leading,
                            spacing: PeakTheme.Spacing.xs
                        ) {
                            ForEach(tagOptions, id: \.self) { tag in
                                Button {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    PeakHaptics.selection()
                                } label: {
                                    Text(tag)
                                        .peakChip(isSelected: selectedTags.contains(tag))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Text("Reflection")
                            .font(PeakTheme.Typography.headline)
                        TextField("What is on your mind?", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                            .padding(PeakTheme.Spacing.md)
                            .background(PeakTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
                    }
                }
                .padding(PeakTheme.Spacing.lg)
            }
            .peakScreenBackground()
            .navigationTitle("Mood Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            rating,
                            energy,
                            note.trimmed.isEmpty ? nil : note.trimmed,
                            selectedTags.sorted()
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
