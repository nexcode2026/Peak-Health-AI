import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CoachViewModel {
    var conversation: CoachConversation?
    var messages: [CoachMessage] = []
    var inputText: String = ""
    var isTyping = false
    var error: PeakError?
    var usageCount: Int = 0
    var usageLimit: Int = PeakConstants.FreeTierLimits.maxAIMessagesPerMonth
    var suggestionChips: [String] = []

    func load(modelContext: ModelContext, ai: any AIServiceProtocol, tier: SubscriptionTier) {
        usageLimit = tier.aiMessageLimit

        let month = AIUsageRecord.currentMonth
        if let record = try? modelContext.fetch(FetchDescriptor<AIUsageRecord>(
            predicate: #Predicate { $0.month == month }
        )).first {
            usageCount = record.messageCount
        }

        if let existing = try? modelContext.fetch(FetchDescriptor<CoachConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )).first {
            conversation = existing
            messages = existing.messages.sorted { $0.createdAt < $1.createdAt }
        } else {
            let newConvo = CoachConversation(title: "Peak Coach")
            modelContext.insert(newConvo)
            conversation = newConvo

            let welcome = CoachMessage(role: .assistant, content: """
            Hi! I'm **Peak Coach** — your private wellness companion. Ask me about your recovery score, sleep, habits, or request a personalized plan.

            \(PeakConstants.medicalDisclaimer)
            """)
            welcome.conversation = newConvo
            modelContext.insert(welcome)
            messages = [welcome]
            try? modelContext.save()
        }

        suggestionChips = ai.suggestionChips(for: buildContext(modelContext: modelContext))
    }

    func send(modelContext: ModelContext, ai: any AIServiceProtocol, tier: SubscriptionTier) async {
        let text = inputText.trimmed
        guard !text.isEmpty, let convo = conversation else { return }

        inputText = ""
        error = nil

        let userMsg = CoachMessage(role: .user, content: text)
        userMsg.conversation = convo
        modelContext.insert(userMsg)
        messages.append(userMsg)

        isTyping = true
        defer { isTyping = false }

        let history = messages.dropLast().map { CoachMessageDTO(role: $0.coachRole, content: $0.content) }
        let context = buildContext(modelContext: modelContext)

        do {
            let response = try await ai.sendMessage(text, context: context, history: Array(history), tier: tier, modelContext: modelContext)

            let assistantMsg = CoachMessage(role: .assistant, content: response.content, tokenCount: response.tokenCount)
            assistantMsg.conversation = convo
            modelContext.insert(assistantMsg)
            messages.append(assistantMsg)
            convo.updatedAt = Date()
            usageCount += 1
            suggestionChips = ai.suggestionChips(for: context)
            try? modelContext.save()
            PeakHaptics.light()
        } catch let peakError as PeakError {
            error = peakError
            PeakHaptics.error()
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    func sendChip(_ chip: String, modelContext: ModelContext, ai: any AIServiceProtocol, tier: SubscriptionTier) async {
        inputText = chip
        await send(modelContext: modelContext, ai: ai, tier: tier)
    }

    private func buildContext(modelContext: ModelContext) -> CoachContext {
        var context = CoachContext()
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            context.displayName = profile.displayName
            context.goals = "Recovery target: \(profile.recoveryTarget), Water: \(profile.dailyWaterGoalML)ml, Sleep: \(profile.sleepHoursTarget)h"
        }

        let today = Date().startOfDay
        if let score = try? modelContext.fetch(FetchDescriptor<RecoveryScore>(
            predicate: #Predicate { $0.date == today }
        )).first {
            context.todayRecoveryScore = score.overallScore
            context.recoveryLabel = PeakTheme.recoveryLabel(for: score.overallScore)
            context.sleepHours = score.factors.sleepHours
            context.hydrationPercent = score.factors.hydrationPercent
            context.habitsCompleted = score.factors.habitsCompleted
            context.habitsTotal = score.factors.habitsTotal
            context.moodRating = score.factors.moodRating
        }

        return context
    }
}