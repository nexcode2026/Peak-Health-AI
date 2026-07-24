import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CoachViewModel {
    enum QuickLogAction: String, Identifiable, Sendable {
        case water
        case meal
        case workout
        case mood

        var id: String { rawValue }
        var title: String {
            switch self {
            case .water: "Water"
            case .meal: "Meal"
            case .workout: "Training"
            case .mood: "Mood & Energy"
            }
        }
    }

    var conversations: [CoachConversation] = []
    var conversation: CoachConversation?
    var messages: [CoachMessage] = []
    var inputText: String = ""
    var isTyping = false
    var error: PeakError?
    var usageCount: Int = 0
    var usageLimit: Int = PeakConstants.FreeTierLimits.maxAIMessagesPerMonth
    var suggestionChips: [String] = []
    var selectedDate: Date = .now
    var historyWindowDays = 7
    var usesConversationMemory = true
    var coachTone: CoachTone = .supportive
    var pendingLogAction: QuickLogAction?

    func configure(memoryEnabled: Bool, historyDays: Int, tone: CoachTone) {
        usesConversationMemory = memoryEnabled
        historyWindowDays = min(30, max(1, historyDays))
        coachTone = tone
    }

    func load(modelContext: ModelContext, ai: any AIServiceProtocol, tier: SubscriptionTier) {
        usageLimit = tier.aiMessageLimit

        let month = AIUsageRecord.currentMonth
        if let record = try? modelContext.fetch(FetchDescriptor<AIUsageRecord>(
            predicate: #Predicate { $0.month == month }
        )).first {
            usageCount = record.messageCount
        }

        refreshConversations(modelContext: modelContext)
        if let current = conversation ?? conversations.first {
            selectConversation(current)
        } else {
            createConversation(modelContext: modelContext)
        }

        suggestionChips = ai.suggestionChips(for: buildContext(modelContext: modelContext))
    }

    func refreshConversations(modelContext: ModelContext) {
        conversations = (try? modelContext.fetch(FetchDescriptor<CoachConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))) ?? []
    }

    func createConversation(modelContext: ModelContext) {
        guard conversations.count < PeakConstants.FreeTierLimits.maxCoachConversations else {
            error = .invalidInput("You can keep up to \(PeakConstants.FreeTierLimits.maxCoachConversations) Coach chats.")
            return
        }

        let newConversation = CoachConversation(title: "New chat")
        modelContext.insert(newConversation)
        let welcome = CoachMessage(role: .assistant, content: """
        Hi — I’m **Peak Coach**. I can compare days, explain your live recovery signals, remember themes you approve, and help log water, meals, workouts, or mood.

        What would make today feel like progress?

        \(PeakConstants.medicalDisclaimer)
        """)
        welcome.conversation = newConversation
        modelContext.insert(welcome)
        try? modelContext.save()
        refreshConversations(modelContext: modelContext)
        selectConversation(newConversation)
    }

    func selectConversation(_ selected: CoachConversation) {
        conversation = selected
        messages = (selected.messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func deleteConversation(_ selected: CoachConversation, modelContext: ModelContext) {
        let wasSelected = selected.id == conversation?.id
        modelContext.delete(selected)
        try? modelContext.save()
        refreshConversations(modelContext: modelContext)
        if wasSelected {
            if let next = conversations.first {
                selectConversation(next)
            } else {
                createConversation(modelContext: modelContext)
            }
        }
    }

    func renameConversation(_ selected: CoachConversation, title: String, modelContext: ModelContext) {
        let cleanTitle = title.trimmed
        guard !cleanTitle.isEmpty else { return }
        selected.title = String(cleanTitle.prefix(48))
        selected.updatedAt = .now
        try? modelContext.save()
        refreshConversations(modelContext: modelContext)
    }

    func send(modelContext: ModelContext, ai: any AIServiceProtocol, tier: SubscriptionTier) async {
        let text = inputText.trimmed
        guard !text.isEmpty, let convo = conversation else { return }

        inputText = ""
        error = nil

        let userMessage = CoachMessage(role: .user, content: text)
        userMessage.conversation = convo
        modelContext.insert(userMessage)
        messages.append(userMessage)
        updateAutomaticTitle(for: convo, from: text)

        if let logAction = requestedQuickLog(from: text) {
            let assistantMessage = CoachMessage(
                role: .assistant,
                content: "Absolutely — I opened the **\(logAction.title)** logger for \(selectedDate.isToday ? "today" : selectedDate.formatted(date: .abbreviated, time: .omitted)). Review the details, then tap Save."
            )
            assistantMessage.conversation = convo
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            convo.updatedAt = .now
            try? modelContext.save()
            pendingLogAction = logAction
            refreshConversations(modelContext: modelContext)
            PeakHaptics.light()
            return
        }

        isTyping = true
        defer { isTyping = false }

        let history = messages.dropLast().map { CoachMessageDTO(role: $0.coachRole, content: $0.content) }
        let context = buildContext(modelContext: modelContext)

        do {
            let response = try await ai.sendMessage(
                text,
                context: context,
                history: Array(history),
                tier: tier,
                modelContext: modelContext
            )

            let assistantMessage = CoachMessage(
                role: .assistant,
                content: response.content,
                tokenCount: response.tokenCount
            )
            assistantMessage.conversation = convo
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)
            convo.updatedAt = .now
            usageCount += 1
            suggestionChips = ai.suggestionChips(for: context)
            try? modelContext.save()
            refreshConversations(modelContext: modelContext)
            PeakHaptics.light()
        } catch let peakError as PeakError {
            error = peakError
            PeakHaptics.error()
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    func sendChip(
        _ chip: String,
        modelContext: ModelContext,
        ai: any AIServiceProtocol,
        tier: SubscriptionTier
    ) async {
        inputText = chip
        await send(modelContext: modelContext, ai: ai, tier: tier)
    }

    func refreshSuggestions(modelContext: ModelContext, ai: any AIServiceProtocol) {
        suggestionChips = ai.suggestionChips(for: buildContext(modelContext: modelContext))
    }

    private func updateAutomaticTitle(for conversation: CoachConversation, from message: String) {
        guard conversation.title == "New chat" else { return }
        let words = message.split(separator: " ").prefix(6).joined(separator: " ")
        conversation.title = String(words.prefix(48))
    }

    private func requestedQuickLog(from message: String) -> QuickLogAction? {
        let lower = message.lowercased()
        let isRequest = ["log", "track", "record", "add"].contains { lower.contains($0) }
        guard isRequest else { return nil }
        if lower.contains("water") || lower.contains("hydrat") || lower.contains("drink") { return .water }
        if lower.contains("meal") || lower.contains("food") || lower.contains("breakfast")
            || lower.contains("lunch") || lower.contains("dinner") { return .meal }
        if lower.contains("workout") || lower.contains("exercise") || lower.contains("run")
            || lower.contains("walk") || lower.contains("lift") { return .workout }
        if lower.contains("mood") || lower.contains("energy") || lower.contains("check-in")
            || lower.contains("check in") { return .mood }
        return nil
    }

    private func buildContext(modelContext: ModelContext) -> CoachContext {
        var context = CoachContext()
        context.selectedDate = selectedDate.formatted(date: .complete, time: .omitted)
        context.coachTone = coachTone

        let day = selectedDate.startOfDay
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)

        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            let units = UnitFormatter(system: UnitSystem(preferredUnits: profile.preferredUnits))
            context.displayName = profile.displayName
            context.goals = "Recovery target: \(profile.recoveryTarget), Water: \(units.formatWater(profile.dailyWaterGoalML)), Sleep: \(profile.sleepHoursTarget)h, Calories: \(profile.dailyCalorieGoal), Protein: \(profile.dailyProteinGoalG)g"
            context.allowsOpenAI = profile.useOpenAIAPI
            context.wellnessStatus = profile.wellnessStatus.title

            let water = (try? modelContext.fetch(FetchDescriptor<HydrationLog>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay }
            )))?.reduce(0) { $0 + $1.amountML } ?? 0
            let meals = (try? modelContext.fetch(FetchDescriptor<FoodLog>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay }
            ))) ?? []
            let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay }
            ))) ?? []
            let moods = (try? modelContext.fetch(FetchDescriptor<MoodReflection>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay }
            ))) ?? []
            context.hydrationPercent = min(1, Double(water) / Double(max(1, profile.dailyWaterGoalML)))
            context.moodRating = moods.last?.moodRating ?? 0
            let calories = meals.reduce(0) { $0 + $1.calories }
            let protein = meals.reduce(0) { $0 + $1.proteinG }
            let energy = moods.last.map { "\($0.energyLevel)/5" } ?? "not logged"
            context.daySummary = "Hydration \(units.formatWater(water)); nutrition \(calories) kcal and \(Int(protein))g protein across \(meals.count) meals; \(workouts.count) workouts; energy \(energy)."

            if profile.genderOption == .female && profile.cycleTrackingEnabled {
                let entries = (try? modelContext.fetch(FetchDescriptor<CycleEntry>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ))) ?? []
                let summary = CycleTrackingSummary.make(
                    entries: entries,
                    averageCycleLength: profile.averageCycleLength,
                    periodLength: profile.averagePeriodLength
                )
                context.cycleTrackingEnabled = true
                context.cycleSummary = summary.cycleDay.map { "Estimated cycle day \($0); \(summary.phase)." }
                    ?? "No period start has been logged yet."
            }
        }

        if let score = try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date == day }
        )).first {
            context.todayRecoveryScore = score.overallScore
            context.recoveryLabel = PeakTheme.recoveryLabel(for: score.overallScore)
            context.sleepHours = score.factors.sleepHours
            context.habitsCompleted = score.factors.habitsCompleted
            context.habitsTotal = score.factors.habitsTotal
            if context.moodRating == 0 { context.moodRating = score.factors.moodRating }
        }

        let historyStart = Calendar.current.date(
            byAdding: .day,
            value: -(historyWindowDays - 1),
            to: day
        ) ?? day
        let scores = (try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date >= historyStart && $0.date < nextDay },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        if !scores.isEmpty {
            let averageRecovery = scores.map(\.overallScore).reduce(0, +) / scores.count
            let averageSleep = scores.map(\.factors.sleepHours).reduce(0, +) / Double(scores.count)
            let direction = (scores.last?.overallScore ?? averageRecovery) - (scores.first?.overallScore ?? averageRecovery)
            context.recentTrend = direction > 5 ? "improving" : direction < -5 ? "declining" : "steady"
            context.recentDataSummary = "\(scores.count) recorded days in the last \(historyWindowDays): average recovery \(averageRecovery), average sleep \(averageSleep.formattedOneDecimal)h, trend \(context.recentTrend)."
        }

        if usesConversationMemory {
            let allMessages = (try? modelContext.fetch(FetchDescriptor<CoachMessage>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            ))) ?? []
            let remembered = allMessages
                .filter { $0.coachRole == .user && $0.conversation?.id != conversation?.id }
                .prefix(8)
                .map(\.content)
                .joined(separator: " | ")
            context.memorySummary = String(remembered.prefix(1_000))
        }

        return context
    }
}
