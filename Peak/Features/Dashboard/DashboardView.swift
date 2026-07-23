import CoreLocation
import SwiftData
import SwiftUI
import WeatherKit

struct DashboardView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var cycleEntries: [CycleEntry]
    @State private var viewModel = DashboardViewModel()
    @State private var quickAction: DashboardViewModel.QuickAction?
    @State private var selectedDate = Date().startOfDay
    @State private var showTodayEditor = ProcessInfo.processInfo.arguments.contains("-PeakShowTodayEditor")
    @State private var weather = PeakWeatherService()
    @Binding private var requestedQuickAction: DashboardViewModel.QuickAction?
    var onProfileTapped: () -> Void = {}

    init(
        requestedQuickAction: Binding<DashboardViewModel.QuickAction?> = .constant(nil),
        onProfileTapped: @escaping () -> Void = {}
    ) {
        _requestedQuickAction = requestedQuickAction
        self.onProfileTapped = onProfileTapped
    }

    private var snapshot: DailyHealthSnapshot {
        DailyHealthSnapshot.build(
            metrics: viewModel.healthMetrics,
            hydrationML: viewModel.hydrationML,
            hydrationGoal: viewModel.hydrationGoal,
            calories: viewModel.todayCalories,
            calorieGoal: viewModel.calorieGoal,
            protein: viewModel.todayProtein,
            habitsCompleted: viewModel.habitsCompleted,
            habitsTotal: viewModel.habitsTotal
        )
    }

    private var liveSteps: Int { viewModel.stepsDisplay }

    private var liveSleepHours: Double { viewModel.sleepHoursDisplay }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.xl) {
                    headerSection
                    statusWeatherRow
                    ForEach(visibleSections) { section in
                        dashboardSection(section)
                    }
                    syncStatusBanner
                    DisclaimerBanner(compact: true)
                    editTodayButton
                }
                .padding(.horizontal, PeakTheme.Spacing.md)
                .peakContentInsets()
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .refreshable {
                if selectedDate.isToday { await container.liveSync.manualRefresh() }
                await viewModel.load(date: selectedDate, modelContext: modelContext, container: container)
            }
            .overlay {
                if viewModel.isLoading && viewModel.todayScore == nil {
                    LoadingView(message: "Syncing Apple Health...")
                }
            }
            .sheet(item: $quickAction) { action in
                quickActionSheet(action)
                    .onDisappear { refreshDashboard() }
            }
            .sheet(isPresented: $showTodayEditor) {
                TodayEditorSheet(profile: currentProfile, modelContext: modelContext)
            }
        }
        .task {
            weather.startIfAuthorized()
            await viewModel.load(date: selectedDate, modelContext: modelContext, container: container)
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await viewModel.load(date: newDate, modelContext: modelContext, container: container) }
        }
        .onChange(of: requestedQuickAction) { _, action in
            guard let action else { return }
            quickAction = action
            requestedQuickAction = nil
        }
        .onChange(of: container.liveSync.syncPulse) { _, _ in
            guard selectedDate.isToday else { return }
            Task { await viewModel.load(date: selectedDate, modelContext: modelContext, container: container) }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            DayNavigator(selectedDate: $selectedDate, compact: true)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onProfileTapped) {
                AvatarView(
                    name: currentProfile?.displayName ?? "P",
                    avatarData: currentProfile?.avatarData,
                    size: 34
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile and settings")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(PeakTheme.Typography.largeTitle)
                    .foregroundStyle(PeakTheme.textPrimary)
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(PeakTheme.Typography.caption)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
            Spacer()
            if selectedDate.isToday {
                LiveSyncBadge(
                    isLive: container.liveSync.isLive,
                    lastSync: container.liveSync.lastSyncDate,
                    hasWatch: container.liveSync.hasAppleWatch
                )
            } else {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.lavender)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassCapsule(tint: PeakTheme.lavender.opacity(0.10))
            }
        }
        .padding(.top, PeakTheme.Spacing.sm)
        .cardAppear(index: 0)
    }

    private var greeting: String {
        guard selectedDate.isToday else { return "Daily Overview" }
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    private var currentProfile: UserProfile? { profiles.first }
    private var displayFormatter: UnitFormatter { UnitFormatter(system: viewModel.unitSystem) }

    private var visibleSections: [TodaySection] {
        let stored = currentProfile?.todaySectionOrder
            .split(separator: ",")
            .compactMap { TodaySection(rawValue: String($0)) } ?? []
        var ordered = stored.isEmpty ? TodaySection.defaultOrder : stored
        for missing in TodaySection.defaultOrder where !ordered.contains(missing) { ordered.append(missing) }
        let hidden = Set((currentProfile?.todayHiddenSections ?? "").split(separator: ",").map(String.init))
        return ordered.filter { section in
            section != .quickLog
                && !hidden.contains(section.rawValue)
                && (section != .cycle || cycleTrackingAvailable)
        }
    }

    private var cycleTrackingAvailable: Bool {
        currentProfile?.genderOption == .female && currentProfile?.cycleTrackingEnabled == true
    }

    @ViewBuilder
    private func dashboardSection(_ section: TodaySection) -> some View {
        switch section {
        case .quickLog:
            EmptyView()
        case .plan:
            dailyPlanSection
        case .yourDay:
            yourDaySection
        case .health:
            healthMonitoringSection
        case .cycle:
            if cycleTrackingAvailable { cyclePreview }
        case .habits:
            habitsPreview
        case .insight:
            insightCard
        case .achievements:
            achievementsSection
        }
    }

    private var statusWeatherRow: some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            Menu {
                Picker("Daily status", selection: wellnessStatusBinding) {
                    ForEach(WellnessStatus.allCases) { status in
                        Text("\(status.emoji) \(status.title)").tag(status)
                    }
                }
            } label: {
                statusPill
            }

            Button { weather.requestOrRefresh() } label: {
                HStack(spacing: 7) {
                    Text(weather.conditionEmoji).font(.title3)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(weather.temperatureC.map { displayFormatter.formatTemperature($0) } ?? "Weather")
                                .font(PeakTheme.Typography.caption).fontWeight(.bold)
                            Text(weather.locationName)
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.textSecondary)
                                .lineLimit(1)
                        }
                        Text("Apple Weather")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                            .lineLimit(1)
                    }
                    if weather.isLoading { ProgressView().controlSize(.mini) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCapsule(tint: PeakTheme.sky.opacity(0.10), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(weather.accessibilitySummary)
        }
        .cardAppear(index: 1)
    }

    private var statusPill: some View {
        let status = currentProfile?.wellnessStatus ?? .normal
        return HStack(spacing: 7) {
            Text(status.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(status.title)
                    .font(PeakTheme.Typography.caption).fontWeight(.bold)
                Text("Daily status")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCapsule(tint: PeakTheme.mint.opacity(0.10), interactive: true)
    }

    private var wellnessStatusBinding: Binding<WellnessStatus> {
        Binding(
            get: { currentProfile?.wellnessStatus ?? .normal },
            set: { status in
                currentProfile?.currentWellnessStatus = status.rawValue
                viewModel.wellnessStatus = status
                try? modelContext.save()
                PeakHaptics.selection()
            }
        )
    }

    // MARK: - Quick actions and daily plan

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: selectedDate.isToday ? "Quick Log" : "Add to This Day", icon: "plus.circle.fill")
            HStack(spacing: PeakTheme.Spacing.sm) {
                quickActionButton(.water, title: "Water", icon: "drop.fill", color: PeakTheme.accent)
                quickActionButton(.meal, title: "Meal", icon: "fork.knife", color: PeakTheme.gold)
                quickActionButton(.mood, title: "Mood", icon: "face.smiling.fill", color: PeakTheme.rose)
                quickActionButton(.workout, title: "Workout", icon: "figure.run", color: PeakTheme.coral)
            }
        }
        .cardAppear(index: 1)
    }

    private func quickActionButton(
        _ action: DashboardViewModel.QuickAction,
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        Button {
            quickAction = action
            PeakHaptics.selection()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PeakTheme.Spacing.sm)
            .background(color.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var dailyPlanSection: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.isToday ? "Today's Peak Plan" : "Day Completion")
                            .font(PeakTheme.Typography.headline)
                        Text("\(Int(viewModel.dailyPlanProgress * 100))% aligned")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                    ProgressRing(
                        progress: viewModel.dailyPlanProgress,
                        label: "Plan",
                        value: "\(viewModel.dailyPlan.filter(\.isComplete).count)/\(viewModel.dailyPlan.count)",
                        color: PeakTheme.mint,
                        size: 52
                    )
                }

                ForEach(viewModel.dailyPlan) { item in
                    dailyPlanRow(item)
                    if item.id != viewModel.dailyPlan.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .cardAppear(index: 2)
    }

    private func dailyPlanRow(_ item: DashboardViewModel.DailyPlanItem) -> some View {
        let color = planColor(item.tone)
        return HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
            ZStack {
                Circle().fill(color.opacity(0.12))
                Image(systemName: item.icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(PeakTheme.Typography.subheadline)
                    .foregroundStyle(PeakTheme.textPrimary)
                Text(item.detail)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: item.progress)
                    .tint(color)
            }

            if let action = item.action {
                Button {
                    quickAction = action
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(action.rawValue)")
            } else if item.isComplete {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(PeakTheme.mint)
            }
        }
    }

    private func planColor(_ tone: DashboardViewModel.DailyPlanItem.Tone) -> Color {
        switch tone {
        case .recovery: PeakTheme.lavender
        case .hydration: PeakTheme.accent
        case .nutrition: PeakTheme.gold
        case .movement: PeakTheme.coral
        case .mindfulness: PeakTheme.rose
        case .habits: PeakTheme.mint
        }
    }

    @ViewBuilder
    private func quickActionSheet(_ action: DashboardViewModel.QuickAction) -> some View {
        switch action {
        case .water:
            LogWaterSheet(date: selectedDate)
        case .meal:
            LogFoodSheet(date: selectedDate)
        case .workout:
            LogWorkoutSheet(date: selectedDate)
        case .mood:
            LogMoodSheet { rating, energy, note, tags in
                saveMood(rating: rating, energy: energy, note: note, tags: tags)
            }
        }
    }

    private func saveMood(rating: Int, energy: Int, note: String?, tags: [String]) {
        let today = selectedDate.startOfDay
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let existing = try? modelContext.fetch(FetchDescriptor<MoodReflection>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
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
                date: today
            ))
        }
        try? modelContext.save()
        PeakHaptics.success()
        refreshDashboard()
    }

    private func refreshDashboard() {
        Task { await viewModel.load(date: selectedDate, modelContext: modelContext, container: container) }
    }

    // MARK: - User-selected Today layout

    @ViewBuilder
    private var yourDaySection: some View {
        if currentProfile?.metricLayout == .compact {
            pillarsGrid
        } else {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                SectionHeaderView(title: "Your Day", icon: "sparkles")
                recoveryExpanded
                sleepExpanded
                strainExpanded
                nutritionWaterExpanded
            }
        }
    }

    private var healthMonitoringSection: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            NavigationLink {
                HealthMonitoringView(snapshot: snapshot, profile: currentProfile, date: selectedDate)
            } label: {
                HStack {
                    Label("Health Monitoring", systemImage: "heart.text.square.fill")
                        .font(PeakTheme.Typography.headline)
                        .foregroundStyle(PeakTheme.textPrimary)
                    Spacer()
                    Text("See all")
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Text("Your selected Apple Health vitals and body measurements")
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.textSecondary)

            if currentProfile?.healthLayout == .detailed {
                VStack(spacing: PeakTheme.Spacing.sm) {
                    ForEach(visibleHealthMetrics) { metric in
                        healthMetricDetailedCard(metric)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: PeakTheme.Spacing.sm), GridItem(.flexible(), spacing: PeakTheme.Spacing.sm)],
                    spacing: PeakTheme.Spacing.sm
                ) {
                    ForEach(visibleHealthMetrics) { metric in
                        NavigationLink {
                            HealthMonitoringView(snapshot: snapshot, profile: currentProfile, date: selectedDate)
                        } label: {
                            TodayPillarCard(
                                title: metric.shortTitle,
                                value: healthMetricValue(metric),
                                subtitle: healthMetricDetail(metric),
                                icon: metric.icon,
                                color: healthMetricColor(metric),
                                progress: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var visibleHealthMetrics: [HealthMetricType] {
        let stored = currentProfile?.todayHealthMetricOrder
            .split(separator: ",")
            .compactMap { HealthMetricType(rawValue: String($0)) } ?? []
        var ordered = stored.isEmpty ? HealthMetricType.allCases : stored
        for metric in HealthMetricType.allCases where !ordered.contains(metric) { ordered.append(metric) }
        let hidden = Set((currentProfile?.todayHiddenHealthMetrics ?? "").split(separator: ",").map(String.init))
        let visible = ordered.filter { !hidden.contains($0.rawValue) }
        return visible.isEmpty ? [.heartRate] : visible
    }

    private func healthMetricDetailedCard(_ metric: HealthMetricType) -> some View {
        NavigationLink {
            HealthMonitoringView(snapshot: snapshot, profile: currentProfile, date: selectedDate)
        } label: {
            HStack(spacing: PeakTheme.Spacing.md) {
                ZStack {
                    Circle().fill(healthMetricColor(metric).opacity(0.12))
                    Image(systemName: metric.icon).foregroundStyle(healthMetricColor(metric))
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title)
                        .font(PeakTheme.Typography.caption)
                        .foregroundStyle(PeakTheme.textSecondary)
                    Text(healthMetricValue(metric))
                        .font(PeakTheme.Typography.title)
                        .foregroundStyle(PeakTheme.textPrimary)
                    Text(healthMetricDetail(metric))
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(PeakTheme.textSecondary.opacity(0.5))
            }
            .padding(PeakTheme.Spacing.md)
            .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: healthMetricColor(metric).opacity(0.055), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func healthMetricValue(_ metric: HealthMetricType) -> String {
        switch metric {
        case .weight:
            if let kg = snapshot.bodyMassKg ?? currentProfile?.weightKg, kg > 0 { return displayFormatter.formatWeight(kg) }
            return "No data"
        case .heartRate: return snapshot.averageHeartRate.map { "\(Int($0)) bpm" } ?? "No data"
        case .respiratoryRate: return snapshot.respiratoryRate.map { "\(String(format: "%.1f", $0))/min" } ?? "No data"
        case .bloodPressure:
            guard let systolic = snapshot.bloodPressureSystolic, let diastolic = snapshot.bloodPressureDiastolic else { return "No data" }
            return "\(Int(systolic))/\(Int(diastolic))"
        case .bloodOxygen: return snapshot.oxygenSaturation.map { "\(Int($0.rounded()))%" } ?? "No data"
        case .height:
            if let cm = snapshot.heightCm ?? currentProfile?.heightCm, cm > 0 { return displayFormatter.formatHeight(cm) }
            return "No data"
        case .restingHeartRate: return snapshot.restingHeartRate.map { "\(Int($0)) bpm" } ?? "No data"
        case .temperature: return snapshot.bodyTemperatureC.map(displayFormatter.formatTemperature) ?? "No data"
        case .sleep: return snapshot.sleepHours > 0 ? "\(snapshot.sleepHours.formattedOneDecimal) h" : "No data"
        }
    }

    private func healthMetricDetail(_ metric: HealthMetricType) -> String {
        switch metric {
        case .weight, .height: "Latest Apple Health measurement"
        case .heartRate: "Daily average"
        case .respiratoryRate: "Breaths per minute"
        case .bloodPressure: "Systolic / diastolic · mmHg"
        case .bloodOxygen: "Oxygen saturation"
        case .restingHeartRate: "Resting baseline"
        case .temperature: "Latest body temperature"
        case .sleep: snapshot.sleepHours > 0 ? "Deep \(Int(snapshot.deepSleepHours * 60))m · REM \(Int(snapshot.remSleepHours * 60))m" : "Awaiting sleep data"
        }
    }

    private func healthMetricColor(_ metric: HealthMetricType) -> Color {
        switch metric {
        case .weight: PeakTheme.gold
        case .heartRate: PeakTheme.coral
        case .respiratoryRate: PeakTheme.mint
        case .bloodPressure: PeakTheme.rose
        case .bloodOxygen: PeakTheme.sky
        case .height: PeakTheme.teal
        case .restingHeartRate: PeakTheme.ultraviolet
        case .temperature: PeakTheme.coral
        case .sleep: PeakTheme.lavender
        }
    }

    private var cyclePreview: some View {
        let profile = currentProfile
        let summary = CycleTrackingSummary.make(
            entries: cycleEntries,
            averageCycleLength: profile?.averageCycleLength ?? 28,
            periodLength: profile?.averagePeriodLength ?? 5
        )
        return NavigationLink {
            if let profile { CycleTrackingView(profile: profile) }
        } label: {
            PeakCard {
                HStack(spacing: PeakTheme.Spacing.md) {
                    ZStack {
                        Circle().fill(PeakTheme.rose.opacity(0.12))
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(PeakTheme.rose)
                    }
                    .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cycle Tracking").font(PeakTheme.Typography.headline)
                        Text(summary.cycleDay.map { "Day \($0) · \(summary.phase)" } ?? "Log a period day to begin")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var editTodayButton: some View {
        Button { showTodayEditor = true } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Today View").font(PeakTheme.Typography.headline)
                    Text("Rearrange sections and customize Your Day or Health Monitoring cards")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(PeakTheme.textPrimary)
            .padding(PeakTheme.Spacing.md)
            .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.ultraviolet.opacity(0.07), interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vertical pillars grid (compact layout)

    private var pillarsGrid: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Your Day", icon: "sparkles")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: PeakTheme.Spacing.sm), GridItem(.flexible(), spacing: PeakTheme.Spacing.sm)],
                spacing: PeakTheme.Spacing.sm
            ) {
                pillarLink(
                    RecoveryDetailView(score: viewModel.todayScore?.overallScore ?? 0, snapshot: snapshot)
                ) {
                    TodayPillarCard(
                        title: "Recovery",
                        value: "\(viewModel.todayScore?.overallScore ?? 0)",
                        subtitle: PeakTheme.recoveryLabel(for: viewModel.todayScore?.overallScore ?? 0),
                        icon: "bolt.heart.fill",
                        color: PeakTheme.scoreColor(viewModel.todayScore?.overallScore ?? 0),
                        progress: Double(viewModel.todayScore?.overallScore ?? 0) / 100,
                        isPrimary: true
                    )
                }

                pillarLink(SleepDetailView(snapshot: snapshot, goalHours: viewModel.sleepTarget)) {
                    TodayPillarCard(
                        title: "Sleep",
                        value: liveSleepHours > 0 ? liveSleepHours.formattedOneDecimal + "h" : "—",
                        subtitle: viewModel.healthMetrics.map { "Quality \(Int($0.sleepQuality * 10))/10" } ?? "Awaiting data",
                        icon: "moon.zzz.fill",
                        color: PeakTheme.lavender,
                        progress: viewModel.sleepProgress
                    )
                }

                pillarLink(ActivityDetailView(snapshot: snapshot)) {
                    TodayPillarCard(
                        title: "Strain",
                        value: "\(viewModel.strainPercent)%",
                        subtitle: "\(viewModel.activeCaloriesDisplay) active kcal",
                        icon: "flame.fill",
                        color: PeakTheme.coral,
                        progress: Double(viewModel.strainPercent) / 100
                    )
                }

                pillarLink(NutritionDetailView(snapshot: snapshot)) {
                    TodayPillarCard(
                        title: "Nutrition",
                        value: "\(viewModel.todayCalories)",
                        subtitle: "of \(viewModel.calorieGoal) kcal",
                        icon: "fork.knife",
                        color: PeakTheme.gold,
                        progress: viewModel.calorieProgress
                    )
                }

                pillarLink(HydrationDetailView(snapshot: snapshot)) {
                    TodayPillarCard(
                        title: "Water",
                        value: displayFormatter.formatWater(viewModel.hydrationML),
                        subtitle: displayFormatter.formatWaterGoal(viewModel.hydrationGoal),
                        icon: "drop.fill",
                        color: PeakTheme.accent,
                        progress: viewModel.hydrationProgress
                    )
                }
                .gridCellColumns(2)
            }
        }
        .cardAppear(index: 1)
    }

    private func pillarLink<D: View>(_ destination: D, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink(destination: { destination }, label: { label() })
            .buttonStyle(.plain)
    }

    // MARK: - Expanded sections

    private var recoveryExpanded: some View {
        NavigationLink {
            RecoveryDetailView(score: viewModel.todayScore?.overallScore ?? 0, snapshot: snapshot)
        } label: {
            PeakCard(padding: PeakTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                    sectionLabel("Recovery Overview", icon: "bolt.heart.fill", color: PeakTheme.accent)

                    HStack(alignment: .center, spacing: PeakTheme.Spacing.lg) {
                        ZStack {
                            BreathingGlow(
                                color: PeakTheme.scoreColor(viewModel.todayScore?.overallScore ?? 0),
                                size: 140
                            )
                            PremiumRecoveryGauge(score: viewModel.todayScore?.overallScore ?? 0, size: 120)
                        }

                        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                            if let score = viewModel.todayScore {
                                FactorBar(label: "Sleep", score: score.sleepScore, color: PeakTheme.lavender)
                                FactorBar(label: "HRV / Heart", score: score.hrvScore, color: PeakTheme.mint)
                                FactorBar(label: "Activity", score: score.activityScore, color: PeakTheme.sky)
                                FactorBar(label: "Hydration", score: score.hydrationScore, color: PeakTheme.accent)
                            } else {
                                Text("Connect Apple Health and log habits to generate your recovery score.")
                                    .font(PeakTheme.Typography.caption)
                                    .foregroundStyle(PeakTheme.textSecondary)
                            }
                        }
                    }

                    if let explanation = viewModel.todayScore?.explanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .cardAppear(index: 2)
    }

    private var sleepExpanded: some View {
        NavigationLink {
            SleepDetailView(snapshot: snapshot, goalHours: viewModel.sleepTarget)
        } label: {
            PeakCard {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                    sectionLabel("Sleep", icon: "moon.zzz.fill", color: PeakTheme.lavender)

                    HStack(alignment: .center, spacing: PeakTheme.Spacing.lg) {
                        MetricGauge(
                            progress: viewModel.sleepProgress,
                            value: liveSleepHours > 0 ? liveSleepHours.formattedOneDecimal + "h" : "—",
                            label: "Sleep Goal",
                            color: PeakTheme.lavender,
                            size: 112
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(viewModel.sleepProgress * 100))% of goal")
                                .font(PeakTheme.Typography.title)
                                .foregroundStyle(PeakTheme.textPrimary)
                            Text("Target \(viewModel.sleepTarget.formattedOneDecimal) hours")
                                .font(PeakTheme.Typography.caption)
                                .foregroundStyle(PeakTheme.textSecondary)
                            if let quality = viewModel.healthMetrics?.sleepQuality, quality > 0 {
                                Label("Quality \(Int(quality * 100))%", systemImage: "sparkles")
                                    .font(PeakTheme.Typography.micro)
                                    .foregroundStyle(PeakTheme.mint)
                            }
                        }
                        Spacer()
                    }

                    if let m = viewModel.healthMetrics {
                        HStack {
                            sleepStagePill("Deep", value: m.deepSleepMinutes, color: PeakTheme.midnight)
                            sleepStagePill("REM", value: m.remSleepMinutes, color: PeakTheme.lavender)
                            sleepStagePill("Quality", value: m.sleepQuality * 100, color: PeakTheme.mint, isPercent: true)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .cardAppear(index: 3)
    }

    private func sleepStagePill(_ label: String, value: Double, color: Color, isPercent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(isPercent ? "\(Int(value))%" : "\(Int(value))m")
                .font(PeakTheme.Typography.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .padding(.horizontal, 8)
    }

    private var strainExpanded: some View {
        NavigationLink {
            ActivityDetailView(snapshot: snapshot)
        } label: {
            PeakCard {
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                    sectionLabel("Strain & Activity", icon: "figure.run", color: PeakTheme.coral)

                    HStack(spacing: PeakTheme.Spacing.lg) {
                        MetricGauge(
                            progress: Double(viewModel.strainPercent) / 100,
                            value: "\(viewModel.strainPercent)%",
                            label: "Strain",
                            color: PeakTheme.coral,
                            size: 112
                        )

                        VStack(spacing: PeakTheme.Spacing.sm) {
                            compactActivityStat("Steps", value: "\(liveSteps)", icon: "figure.walk", color: PeakTheme.mint)
                            compactActivityStat("Active", value: "\(viewModel.activeCaloriesDisplay) kcal", icon: "flame.fill", color: PeakTheme.coral)
                            compactActivityStat("Exercise", value: viewModel.healthMetrics.map { "\(Int($0.exerciseMinutes)) min" } ?? "—", icon: "timer", color: PeakTheme.sky)
                            compactActivityStat("Workouts", value: "\(viewModel.todayWorkouts)", icon: "dumbbell.fill", color: PeakTheme.lavender)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .cardAppear(index: 4)
    }

    private func activityTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: PeakTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(PeakTheme.Typography.subheadline)
                    .fontWeight(.bold)
                Text(label)
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
            }
            Spacer()
        }
        .padding(PeakTheme.Spacing.sm)
        .background(PeakTheme.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
    }

    private func compactActivityStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            Spacer(minLength: 4)
            Text(value)
                .font(PeakTheme.Typography.micro)
                .fontWeight(.bold)
                .foregroundStyle(PeakTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private var nutritionWaterExpanded: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                sectionLabel("Nutrition & Hydration", icon: "leaf.fill", color: PeakTheme.gold)

                HStack(alignment: .top, spacing: PeakTheme.Spacing.md) {
                    NavigationLink {
                        NutritionDetailView(snapshot: snapshot)
                    } label: {
                        VStack(spacing: PeakTheme.Spacing.xs) {
                            MetricGauge(
                                progress: viewModel.calorieProgress,
                                value: "\(viewModel.todayCalories)",
                                label: "Nutrition",
                                color: PeakTheme.gold,
                                size: 112
                            )
                            Text("Goal \(viewModel.calorieGoal) kcal")
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HydrationDetailView(snapshot: snapshot)
                    } label: {
                        VStack(spacing: PeakTheme.Spacing.xs) {
                            MetricGauge(
                                progress: viewModel.hydrationProgress,
                                value: displayFormatter.formatWaterShort(viewModel.hydrationML),
                                label: "Water · \(displayFormatter.waterUnitLabel)",
                                color: PeakTheme.accent,
                                size: 112
                            )
                            Text(displayFormatter.formatWaterGoal(viewModel.hydrationGoal))
                                .font(PeakTheme.Typography.micro)
                                .foregroundStyle(PeakTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: PeakTheme.Spacing.md) {
                    macroChip("Protein", value: "\(Int(viewModel.todayProtein))g", goal: "\(viewModel.proteinGoal)g", color: PeakTheme.coral)
                    macroChip("Workouts", value: "\(viewModel.todayWorkouts)", goal: "today", color: PeakTheme.lavender)
                }
            }
        }
        .cardAppear(index: 5)
    }

    private func nutritionColumn(title: String, value: String, goal: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.textSecondary)
            Text(value)
                .font(PeakTheme.Typography.title)
                .foregroundStyle(color)
            Text(goal)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            ProgressView(value: progress)
                .tint(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroChip(_ label: String, value: String, goal: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
            Text(value).font(PeakTheme.Typography.subheadline).fontWeight(.bold).foregroundStyle(color)
            Text(goal).font(.system(size: 9)).foregroundStyle(PeakTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PeakTheme.Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
    }

    private var heartStrip: some View {
        NavigationLink {
            HeartDetailView(snapshot: snapshot)
        } label: {
            PeakCard {
                HStack(spacing: PeakTheme.Spacing.lg) {
                    heartMetric(
                        label: "Resting HR",
                        value: viewModel.healthMetrics.map { $0.restingHeartRate > 0 ? "\(Int($0.restingHeartRate))" : "—" } ?? "—",
                        unit: "bpm",
                        color: PeakTheme.coral
                    )
                    Divider().frame(height: 40)
                    heartMetric(
                        label: "HRV",
                        value: viewModel.healthMetrics.map { $0.hrvMS > 0 ? "\(Int($0.hrvMS))" : "—" } ?? "—",
                        unit: "ms",
                        color: PeakTheme.mint
                    )
                    Divider().frame(height: 40)
                    heartMetric(
                        label: "Live HR",
                        value: container.liveSync.liveHeartRate.map { "\(Int($0))" } ?? "—",
                        unit: "bpm",
                        color: PeakTheme.accent
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .cardAppear(index: 6)
    }

    private func heartMetric(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(PeakTheme.Typography.headline)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var habitsPreview: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                sectionLabel("Habits Today", icon: "checkmark.circle.fill", color: PeakTheme.mint)
                HStack {
                    ProgressRing(
                        progress: viewModel.habitsTotal > 0 ? Double(viewModel.habitsCompleted) / Double(viewModel.habitsTotal) : 0,
                        label: "Done",
                        value: "\(viewModel.habitsCompleted)/\(viewModel.habitsTotal)",
                        color: PeakTheme.mint
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.habitsCompleted == viewModel.habitsTotal && viewModel.habitsTotal > 0
                             ? "All habits complete!"
                             : "Keep your streak going")
                            .font(PeakTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                        Text("Log habits in the Journal tab")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .cardAppear(index: 7)
    }

    // MARK: - Existing sections (rings, drill-down, insight, badges)

    private var progressRings: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Daily Rings", icon: "circle.hexagongrid.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PeakTheme.Spacing.md) {
                TappableMetricCard(destination: RecoveryDetailView(score: viewModel.todayScore?.overallScore ?? 0, snapshot: snapshot)) {
                    PremiumProgressRing(
                        progress: Double(viewModel.todayScore?.overallScore ?? 0) / 100,
                        label: "Recovery",
                        value: "\(viewModel.todayScore?.overallScore ?? 0)",
                        color: PeakTheme.scoreColor(viewModel.todayScore?.overallScore ?? 0),
                        size: 76
                    )
                    .frame(width: 92)
                }
                TappableMetricCard(destination: SleepDetailView(snapshot: snapshot, goalHours: viewModel.sleepTarget)) {
                    PremiumProgressRing(
                        progress: viewModel.sleepProgress,
                        label: "Sleep",
                        value: liveSleepHours > 0 ? liveSleepHours.formattedOneDecimal + "h" : "—",
                        color: PeakTheme.lavender,
                        size: 76
                    )
                    .frame(width: 92)
                }
                TappableMetricCard(destination: HydrationDetailView(snapshot: snapshot)) {
                    PremiumProgressRing(
                        progress: viewModel.hydrationProgress,
                        label: "Water",
                        value: "\(Int(viewModel.hydrationProgress * 100))%",
                        color: PeakTheme.accent,
                        size: 76
                    )
                    .frame(width: 92)
                }
                TappableMetricCard(destination: ActivityDetailView(snapshot: snapshot)) {
                    PremiumProgressRing(
                        progress: viewModel.moveProgress,
                        label: "Exercise",
                        value: "\(liveSteps)",
                        color: PeakTheme.mint,
                        size: 76
                    )
                    .frame(width: 92)
                }
                TappableMetricCard(destination: NutritionDetailView(snapshot: snapshot)) {
                    PremiumProgressRing(
                        progress: viewModel.calorieProgress,
                        label: "Nutrition",
                        value: "\(viewModel.todayCalories)",
                        color: PeakTheme.coral,
                        size: 76
                    )
                    .frame(width: 92)
                }
                TappableMetricCard(destination: TrackView(initialDate: selectedDate)) {
                    PremiumProgressRing(
                        progress: viewModel.journalProgress,
                        label: "Journal",
                        value: "\(viewModel.habitsCompleted)/\(viewModel.habitsTotal)",
                        color: PeakTheme.rose,
                        size: 76
                    )
                    .frame(width: 92)
                }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, PeakTheme.Spacing.sm)
            }
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
        .cardAppear(index: 8)
    }

    private var drillDownSection: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "All Metrics")

            if let m = viewModel.healthMetrics, hasHealthData(m) {
                VStack(spacing: PeakTheme.Spacing.sm) {
                    drillLink(SleepDetailView(snapshot: snapshot, goalHours: viewModel.sleepTarget)) {
                        DrillDownRow(icon: "moon.zzz.fill", title: "Sleep", value: liveSleepHours > 0 ? liveSleepHours.formattedOneDecimal + "h" : "—", subtitle: "Deep · REM · Quality", color: PeakTheme.lavender)
                    }
                    drillLink(HeartDetailView(snapshot: snapshot)) {
                        DrillDownRow(icon: "heart.fill", title: "Heart", value: liveHeartDisplay(m), subtitle: "HRV & resting heart rate", color: PeakTheme.coral)
                    }
                    drillLink(ActivityDetailView(snapshot: snapshot)) {
                        DrillDownRow(icon: "figure.walk", title: "Activity", value: "\(liveSteps)", subtitle: "Steps · strain · workouts", color: PeakTheme.mint)
                    }
                    drillLink(NutritionDetailView(snapshot: snapshot)) {
                        DrillDownRow(icon: "fork.knife", title: "Nutrition", value: "\(viewModel.todayCalories) kcal", subtitle: "Macros & meal logging", color: PeakTheme.gold)
                    }
                }
            } else {
                connectHealthCard
            }
        }
        .cardAppear(index: 9)
    }

    private func drillLink<D: View>(_ destination: D, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink(destination: { destination }, label: { label() })
            .buttonStyle(.plain)
    }

    private var connectHealthCard: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                HStack {
                    Image(systemName: "heart.text.square").foregroundStyle(PeakTheme.accent)
                    VStack(alignment: .leading) {
                        Text("Connect Apple Health").font(PeakTheme.Typography.headline)
                        Text("Enable Health access to pull sleep, HRV, steps, and workouts from your iPhone & Apple Watch in real time.")
                            .font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                Button("Connect Now") {
                    Task {
                        try? await container.healthKit.requestAuthorization()
                        await container.startHealthLiveSync()
                        await viewModel.load(date: selectedDate, modelContext: modelContext, container: container)
                    }
                }
                .peakButtonStyle()
            }
        }
    }

    private func liveHeartDisplay(_ m: DailyHealthMetrics) -> String {
        if let live = container.liveSync.liveHeartRate { return "\(Int(live)) bpm" }
        if m.restingHeartRate > 0 { return "\(Int(m.restingHeartRate)) bpm" }
        return "—"
    }

    private func hasHealthData(_ m: DailyHealthMetrics) -> Bool {
        m.sleepHours > 0 || m.steps > 0 || m.hrvMS > 0 || m.restingHeartRate > 0 || container.liveSync.isLive
    }

    private var insightCard: some View {
        PeakCard {
            HStack(alignment: .top, spacing: PeakTheme.Spacing.md) {
                Image(systemName: "sparkles").font(.title3).foregroundStyle(PeakTheme.gold).symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                    Text("Daily Insight").font(PeakTheme.Typography.headline)
                    Text(viewModel.dailyInsight).font(PeakTheme.Typography.body).foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
        .cardAppear(index: 10)
    }

    @ViewBuilder
    private var achievementsSection: some View {
        if !viewModel.nearestAchievements.isEmpty || !viewModel.recentAchievements.isEmpty {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.md) {
                if !viewModel.nearestAchievements.isEmpty {
                    SectionHeaderView(title: "Next Badges")
                    ForEach(viewModel.nearestAchievements, id: \.id) { a in
                        AchievementProgressCard(achievement: a)
                    }
                }
                if !viewModel.recentAchievements.isEmpty {
                    SectionHeaderView(title: "Recent Badges")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PeakTheme.Spacing.md) {
                            ForEach(viewModel.recentAchievements, id: \.id) { a in
                                AchievementBadgeView(achievement: a, size: .small)
                            }
                        }
                    }
                }
            }
            .cardAppear(index: 11)
        }
    }

    @ViewBuilder
    private var syncStatusBanner: some View {
        if container.healthData.authorizationStatus == .notDetermined {
            cloudBanner(
                icon: "heart.text.square",
                message: container.healthData.authorizationStatus.displayMessage,
                color: PeakTheme.accent
            )
        } else if !ModelContainerFactory.isICloudAvailable {
            cloudBanner(
                icon: "icloud.slash",
                message: container.cloudKitSync.statusMessage,
                color: PeakTheme.warning
            )
        } else if !ModelContainerFactory.isCloudKitEnabled {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.xs) {
                cloudBanner(
                    icon: "exclamationmark.icloud",
                    message: ModelContainerFactory.lastCloudKitError
                        ?? "CloudKit sync failed. Your data is saved on this device only.",
                    color: PeakTheme.error
                )
                Text("Confirm iCloud Drive is enabled for this iPhone, then use You → Enable iCloud Sync and restart Peak.")
                    .font(PeakTheme.Typography.micro)
                    .foregroundStyle(PeakTheme.textSecondary)
                Button("Enable iCloud Sync") {
                    ModelContainerFactory.enableCloudKitSyncOnNextLaunch()
                }
                .font(PeakTheme.Typography.caption)
                .foregroundStyle(PeakTheme.accent)
            }
        }
    }

    private func cloudBanner(icon: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .padding(PeakTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: PeakTheme.Radius.sm, tint: color.opacity(0.035))
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PeakTheme.Spacing.xs) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(PeakTheme.Typography.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PeakTheme.textSecondary.opacity(0.4))
        }
    }
}

// MARK: - Today customization

private struct TodayEditorSheet: View {
    let profile: UserProfile?
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var order = TodaySection.defaultOrder
    @State private var hidden = Set<TodaySection>()
    @State private var layout: TodayMetricLayout = .detailed
    @State private var healthLayout: TodayMetricLayout = .compact
    @State private var healthOrder = HealthMetricType.allCases
    @State private var hiddenHealthMetrics = Set<HealthMetricType>()

    private var availableOrder: [TodaySection] {
        order.filter {
            $0 != .quickLog
                && ($0 != .cycle || (profile?.genderOption == .female && profile?.cycleTrackingEnabled == true))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Label("Your Day cards", systemImage: "rectangle.3.group.fill")
                            .font(PeakTheme.Typography.headline)
                        Picker("Your Day layout", selection: $layout) {
                            ForEach(TodayMetricLayout.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        layoutPreview
                        Text(layout.detail)
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                    .padding(PeakTheme.Spacing.md)
                    .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.ultraviolet.opacity(0.06))

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Label("Health Monitoring cards", systemImage: "heart.text.square.fill")
                            .font(PeakTheme.Typography.headline)
                        Picker("Health Monitoring layout", selection: $healthLayout) {
                            ForEach(TodayMetricLayout.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        healthLayoutPreview
                        Text(healthLayout == .compact
                             ? "Two-column cards keep every selected vital easy to scan."
                             : "Expanded rows show larger values and supporting context.")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)

                        Text("Displayed metrics")
                            .font(PeakTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .padding(.top, PeakTheme.Spacing.xs)
                        ForEach(healthOrder) { metric in
                            healthMetricRow(metric)
                        }
                    }
                    .padding(PeakTheme.Spacing.md)
                    .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: PeakTheme.coral.opacity(0.055))

                    VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                        Text("Sections").font(PeakTheme.Typography.headline)
                        Text("Use the arrows to arrange Today. The eye button shows or hides each section.")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)

                        ForEach(availableOrder) { section in
                            sectionRow(section)
                        }
                    }
                }
                .padding(PeakTheme.Spacing.md)
                .padding(.bottom, PeakTheme.Spacing.xl)
            }
            .peakScreenBackground()
            .navigationTitle("Edit Today View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { load() }
        }
    }

    private var layoutPreview: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: layout == .compact ? 8 : 12)
                    .fill([PeakTheme.mint, PeakTheme.lavender, PeakTheme.coral, PeakTheme.gold, PeakTheme.accent][index].opacity(0.16))
                    .overlay {
                        Circle()
                            .trim(from: 0, to: Double(index + 4) / 9)
                            .stroke([PeakTheme.mint, PeakTheme.lavender, PeakTheme.coral, PeakTheme.gold, PeakTheme.accent][index], lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                            .padding(layout == .compact ? 10 : 6)
                    }
                    .frame(height: layout == .compact ? 54 : 82)
            }
        }
        .animation(.spring(response: 0.3), value: layout)
    }

    private var healthLayoutPreview: some View {
        Group {
            if healthLayout == .compact {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .fill([PeakTheme.coral, PeakTheme.sky, PeakTheme.mint, PeakTheme.lavender][index].opacity(0.15))
                            .frame(height: 46)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill([PeakTheme.coral, PeakTheme.sky, PeakTheme.mint][index].opacity(0.15))
                            .frame(height: 54)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: healthLayout)
    }

    private func healthMetricRow(_ metric: HealthMetricType) -> some View {
        let isVisible = !hiddenHealthMetrics.contains(metric)
        return HStack(spacing: PeakTheme.Spacing.sm) {
            Image(systemName: metric.icon)
                .foregroundStyle(isVisible ? PeakTheme.coral : PeakTheme.textSecondary)
                .frame(width: 26)
            Text(metric.title)
                .font(PeakTheme.Typography.subheadline)
                .foregroundStyle(isVisible ? PeakTheme.textPrimary : PeakTheme.textSecondary)
            Spacer()
            Button { moveHealthMetric(metric, offset: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(healthOrder.first == metric)
            Button { moveHealthMetric(metric, offset: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(healthOrder.last == metric)
            Button {
                if isVisible { hiddenHealthMetrics.insert(metric) } else { hiddenHealthMetrics.remove(metric) }
                PeakHaptics.selection()
            } label: {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundStyle(isVisible ? PeakTheme.mint : PeakTheme.textSecondary)
            }
        }
        .padding(PeakTheme.Spacing.sm)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.coral.opacity(isVisible ? 0.035 : 0.01), interactive: true)
    }

    private func sectionRow(_ section: TodaySection) -> some View {
        let isVisible = !hidden.contains(section)
        return HStack(spacing: PeakTheme.Spacing.sm) {
            Image(systemName: section.icon)
                .foregroundStyle(isVisible ? PeakTheme.accent : PeakTheme.textSecondary)
                .frame(width: 26)
            Text(section.title)
                .font(PeakTheme.Typography.subheadline)
                .foregroundStyle(isVisible ? PeakTheme.textPrimary : PeakTheme.textSecondary)
            Spacer()
            Button { move(section, offset: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(order.first == section)
            Button { move(section, offset: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(order.last == section)
            Button {
                if isVisible { hidden.insert(section) } else { hidden.remove(section) }
                PeakHaptics.selection()
            } label: {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundStyle(isVisible ? PeakTheme.mint : PeakTheme.textSecondary)
            }
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.accent.opacity(isVisible ? 0.035 : 0.01), interactive: true)
    }

    private func move(_ section: TodaySection, offset: Int) {
        guard let index = order.firstIndex(of: section) else { return }
        let destination = index + offset
        guard order.indices.contains(destination) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            order.swapAt(index, destination)
        }
        PeakHaptics.selection()
    }

    private func moveHealthMetric(_ metric: HealthMetricType, offset: Int) {
        guard let index = healthOrder.firstIndex(of: metric) else { return }
        let destination = index + offset
        guard healthOrder.indices.contains(destination) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            healthOrder.swapAt(index, destination)
        }
        PeakHaptics.selection()
    }

    private func load() {
        guard let profile else { return }
        let stored = profile.todaySectionOrder.split(separator: ",").compactMap { TodaySection(rawValue: String($0)) }
        order = stored.isEmpty ? TodaySection.defaultOrder : stored
        for missing in TodaySection.defaultOrder where !order.contains(missing) { order.append(missing) }
        hidden = Set(profile.todayHiddenSections.split(separator: ",").compactMap { TodaySection(rawValue: String($0)) })
        layout = profile.metricLayout
        healthLayout = profile.healthLayout
        let storedHealth = profile.todayHealthMetricOrder.split(separator: ",").compactMap { HealthMetricType(rawValue: String($0)) }
        healthOrder = storedHealth.isEmpty ? HealthMetricType.allCases : storedHealth
        for missing in HealthMetricType.allCases where !healthOrder.contains(missing) { healthOrder.append(missing) }
        hiddenHealthMetrics = Set(profile.todayHiddenHealthMetrics.split(separator: ",").compactMap { HealthMetricType(rawValue: String($0)) })
    }

    private func save() {
        profile?.todayMetricLayout = layout.rawValue
        profile?.healthMetricLayout = healthLayout.rawValue
        profile?.todaySectionOrder = order.map(\.rawValue).joined(separator: ",")
        profile?.todayHiddenSections = hidden.map(\.rawValue).sorted().joined(separator: ",")
        profile?.todayHealthMetricOrder = healthOrder.map(\.rawValue).joined(separator: ",")
        profile?.todayHiddenHealthMetrics = hiddenHealthMetrics.map(\.rawValue).sorted().joined(separator: ",")
        try? modelContext.save()
        PeakHaptics.success()
        dismiss()
    }
}

// MARK: - Apple Weather pill

@MainActor
@Observable
private final class PeakWeatherService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let weatherService = WeatherService.shared
    var temperatureC: Double?
    var symbolName = "cloud.sun.fill"
    var conditionName = "Weather unavailable"
    var locationName = "Tap to connect"
    var isLoading = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var conditionEmoji: String {
        if symbolName.contains("thunder") { return "⛈️" }
        if symbolName.contains("snow") || symbolName.contains("sleet") { return "❄️" }
        if symbolName.contains("rain") || symbolName.contains("drizzle") { return "🌧️" }
        if symbolName.contains("fog") || symbolName.contains("haze") { return "🌫️" }
        if symbolName.contains("wind") { return "💨" }
        if symbolName.contains("cloud") { return symbolName.contains("sun") ? "🌤️" : "☁️" }
        return "☀️"
    }

    var accessibilitySummary: String {
        temperatureC.map { "\(conditionName), \(Int($0.rounded())) degrees Celsius, \(locationName), Apple Weather" }
            ?? "Connect location for live Apple Weather"
    }

    func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: locationName = "Location off"
        default: break
        }
    }

    func requestOrRefresh() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: locationName = "Enable Location"
        @unknown default: locationName = "Weather unavailable"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            locationName = "Location off"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await loadWeather(at: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        locationName = "Weather unavailable"
    }

    private func loadWeather(at location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let current = weatherService.weather(for: location, including: .current)
            async let places = CLGeocoder().reverseGeocodeLocation(location)
            let weather = try await current
            temperatureC = weather.temperature.converted(to: .celsius).value
            symbolName = weather.symbolName
            conditionName = weather.condition.description
            let placemark = try? await places.first
            let place = placemark?.locality ?? placemark?.administrativeArea ?? "Current location"
            locationName = place
        } catch {
            conditionName = "Weather unavailable"
            locationName = "Try again"
        }
    }
}

#Preview {
    DashboardView()
        .peakPreviewShell()
}
