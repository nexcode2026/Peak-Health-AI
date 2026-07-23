import Foundation
import SwiftData

// MARK: - AI Service Protocol

protocol AIServiceProtocol: Sendable {
    func sendMessage(
        _ message: String,
        context: CoachContext,
        history: [CoachMessageDTO],
        tier: SubscriptionTier,
        modelContext: ModelContext
    ) async throws -> CoachResponse
    func suggestionChips(for context: CoachContext) -> [String]
    var systemPrompt: String { get }
}

struct CoachContext: Sendable {
    var displayName: String = "User"
    var todayRecoveryScore: Int = 0
    var recoveryLabel: String = ""
    var sleepHours: Double = 0
    var hydrationPercent: Double = 0
    var habitsCompleted: Int = 0
    var habitsTotal: Int = 0
    var moodRating: Int = 0
    var goals: String = ""
    var recentTrend: String = ""
}

struct CoachMessageDTO: Sendable {
    let role: CoachRole
    let content: String
}

struct CoachResponse: Sendable {
    let content: String
    let tokenCount: Int
    let usedGrokAPI: Bool
}

// MARK: - Hybrid AI: On-device fallback + optional xAI Grok API

final class AIService: AIServiceProtocol, @unchecked Sendable {
    private let keychain: KeychainService
    private let grokEndpoint = "https://api.x.ai/v1/chat/completions"
    private let grokModel = "grok-3-mini"

    var systemPrompt: String {
        """
        You are Peak Coach, an empathetic, evidence-based wellness coach inside the Peak health app.

        PERSONA: Warm, motivating, concise. Celebrate progress. Never preachy. Use plain language.

        SAFETY (CRITICAL):
        - You are NOT a doctor, therapist, or medical device.
        - Never diagnose conditions or prescribe treatments.
        - For pain, injury, eating disorders, mental health crises, or medication questions → urge professional help.
        - Always include: "This is wellness guidance, not medical advice."

        CAPABILITIES:
        - Explain recovery scores and trends
        - Suggest sustainable micro-habits and 7-day plans
        - Sleep, hydration, and activity balance tips
        - Mood and reflection prompts

        STYLE: Short paragraphs. Bullet points for plans. Ask one follow-up question when helpful.
        """
    }

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func sendMessage(
        _ message: String,
        context: CoachContext,
        history: [CoachMessageDTO],
        tier: SubscriptionTier,
        modelContext: ModelContext
    ) async throws -> CoachResponse {
        try await checkUsageLimit(tier: tier, modelContext: modelContext)

        let contextBlock = buildContextBlock(context)
        let fullSystem = systemPrompt + "\n\nUSER CONTEXT:\n" + contextBlock

        // Try Grok API if key is configured and user opted in
        if let apiKey = keychain.read(for: .grokAPIKey), !apiKey.isEmpty {
            do {
                let response = try await callGrokAPI(
                    apiKey: apiKey,
                    system: fullSystem,
                    history: history,
                    userMessage: message
                )
                await recordUsage(modelContext: modelContext, tokens: response.tokenCount)
                return response
            } catch {
                PeakLogger.ai.warning("Grok API failed, falling back to on-device: \(error.localizedDescription)")
            }
        }

        // On-device fallback (rule-based intelligent responses)
        let response = generateOnDeviceResponse(message: message, context: context)
        await recordUsage(modelContext: modelContext, tokens: response.tokenCount)
        return response
    }

    func suggestionChips(for context: CoachContext) -> [String] {
        var chips = [
            "Why is my recovery score \(context.todayRecoveryScore)?",
            "Create a 7-day recovery plan",
            "How can I sleep better?",
            "Hydration tips for today",
        ]
        if context.habitsCompleted < context.habitsTotal {
            chips.append("Help me finish today's habits")
        }
        if context.moodRating > 0 && context.moodRating < 3 {
            chips.append("I'm feeling low energy")
        }
        return Array(chips.prefix(4))
    }

    // MARK: - Grok API

    private func callGrokAPI(
        apiKey: String,
        system: String,
        history: [CoachMessageDTO],
        userMessage: String
    ) async throws -> CoachResponse {
        var messages: [[String: String]] = [["role": "system", "content": system]]
        for msg in history.suffix(10) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": grokModel,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1024,
        ]

        var request = URLRequest(url: URL(string: grokEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PeakError.aiServiceUnavailable
        }

        struct GrokResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            struct Usage: Decodable { let total_tokens: Int? }
            let choices: [Choice]
            let usage: Usage?
        }

        let decoded = try JSONDecoder().decode(GrokResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? "I'm here to help. Could you rephrase that?"
        let tokens = decoded.usage?.total_tokens ?? content.count / 4

        return CoachResponse(content: content + "\n\n_This is wellness guidance, not medical advice._", tokenCount: tokens, usedGrokAPI: true)
    }

    // MARK: - On-Device Fallback

    private func generateOnDeviceResponse(message: String, context: CoachContext) -> CoachResponse {
        let lower = message.lowercased()
        var response: String

        if lower.contains("recovery") || lower.contains("score") {
            response = """
            Your recovery score today is **\(context.todayRecoveryScore)** (\(context.recoveryLabel)).

            Key factors:
            • Sleep: \(context.sleepHours > 0 ? String(format: "%.1f hours", context.sleepHours) : "no data yet")
            • Hydration: \(Int(context.hydrationPercent * 100))% of goal
            • Habits: \(context.habitsCompleted)/\(context.habitsTotal) done

            To improve: prioritize 7–9h sleep tonight, hit your water goal, and complete remaining habits. Small consistent wins compound.

            _This is wellness guidance, not medical advice._
            """
        } else if lower.contains("sleep") {
            response = """
            **Sleep optimization tips:**
            • Wind down 30 min before bed — dim lights, no screens
            • Keep bedroom cool (65–68°F / 18–20°C)
            • Consistent wake time, even weekends
            • Limit caffeine after 2 PM

            Your target: \(context.goals.isEmpty ? "8 hours" : context.goals). Track trends in Insights.

            _This is wellness guidance, not medical advice._
            """
        } else if lower.contains("plan") || lower.contains("7-day") || lower.contains("7 day") {
            response = """
            **Your 7-Day Recovery Plan:**

            **Days 1–2:** Focus on sleep hygiene. In bed by 10:30 PM. Log mood each morning.
            **Days 3–4:** Hit hydration goal daily. Add a 10-min walk after lunch.
            **Days 5–6:** Complete all micro-habits. Review recovery score trends.
            **Day 7:** Reflect — what worked? Adjust one habit for next week.

            Check Insights for progress. You've got this, \(context.displayName)!

            _This is wellness guidance, not medical advice._
            """
        } else if lower.contains("hydrat") || lower.contains("water") {
            response = """
            You're at **\(Int(context.hydrationPercent * 100))%** of your hydration goal.

            Quick wins:
            • Drink a glass now — tap +1 in Track
            • Set reminders every 2 hours in Settings
            • Front-load water in the morning

            _This is wellness guidance, not medical advice._
            """
        } else if lower.contains("habit") {
            response = """
            Habits today: **\(context.habitsCompleted)/\(context.habitsTotal)** completed.

            Tip: Stack habits onto existing routines (e.g., stretch right after brushing teeth). Start with just 2 minutes — consistency beats intensity.

            _This is wellness guidance, not medical advice._
            """
        } else {
            response = """
            Thanks for reaching out, \(context.displayName)! I'm Peak Coach — here to help with recovery, sleep, habits, and sustainable performance.

            Your recovery today: **\(context.todayRecoveryScore)**. Ask me about your score, a 7-day plan, sleep tips, or hydration.

            _This is wellness guidance, not medical advice._
            """
        }

        return CoachResponse(content: response, tokenCount: response.count / 4, usedGrokAPI: false)
    }

    private func buildContextBlock(_ context: CoachContext) -> String {
        """
        Name: \(context.displayName)
        Recovery: \(context.todayRecoveryScore) (\(context.recoveryLabel))
        Sleep: \(context.sleepHours)h
        Hydration: \(Int(context.hydrationPercent * 100))%
        Habits: \(context.habitsCompleted)/\(context.habitsTotal)
        Mood: \(context.moodRating > 0 ? "\(context.moodRating)/5" : "not logged")
        Goals: \(context.goals)
        Trend: \(context.recentTrend)
        """
    }

    @MainActor
    private func checkUsageLimit(tier: SubscriptionTier, modelContext: ModelContext) async throws {
        let month = AIUsageRecord.currentMonth
        let descriptor = FetchDescriptor<AIUsageRecord>(
            predicate: #Predicate { $0.month == month }
        )
        let record = try modelContext.fetch(descriptor).first ?? {
            let r = AIUsageRecord(month: month)
            modelContext.insert(r)
            return r
        }()

        if record.messageCount >= tier.aiMessageLimit {
            throw PeakError.aiRateLimitExceeded
        }
    }

    @MainActor
    private func recordUsage(modelContext: ModelContext, tokens: Int) async {
        let month = AIUsageRecord.currentMonth
        let descriptor = FetchDescriptor<AIUsageRecord>(
            predicate: #Predicate { $0.month == month }
        )
        let record: AIUsageRecord
        if let existing = try? modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = AIUsageRecord(month: month)
            modelContext.insert(record)
        }
        record.messageCount += 1
        record.tokenCount += tokens
        record.lastUpdated = Date()
        try? modelContext.save()
    }
}