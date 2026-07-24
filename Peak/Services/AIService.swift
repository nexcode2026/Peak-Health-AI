import CryptoKit
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
    func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult
    var systemPrompt: String { get }
}

enum MealAnalysisSource: String, Sendable {
    case search, photo, barcode, manual
}

struct MealAnalysisRequest: Sendable {
    var query: String?
    var imageData: Data?
    var source: MealAnalysisSource
}

struct MealAnalysisItem: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var serving: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double = 0
    var sugarG: Double = 0
    var saturatedFatG: Double = 0
    var sodiumMg: Double = 0
    var cholesterolMg: Double = 0
    var ingredients: [String] = []
    var confidence: Double
}

struct MealAnalysisResult: Sendable {
    var title: String
    var overview: String
    var items: [MealAnalysisItem]
    var source: MealAnalysisSource
}

struct CoachContext: Sendable {
    var displayName: String = "User"
    var selectedDate: String = "Today"
    var todayRecoveryScore: Int = 0
    var recoveryLabel: String = ""
    var sleepHours: Double = 0
    var hydrationPercent: Double = 0
    var habitsCompleted: Int = 0
    var habitsTotal: Int = 0
    var moodRating: Int = 0
    var goals: String = ""
    var recentTrend: String = ""
    var allowsOpenAI: Bool = false
    var wellnessStatus: String = "Normal"
    var cycleTrackingEnabled: Bool = false
    var cycleSummary: String = ""
    var daySummary: String = ""
    var recentDataSummary: String = ""
    var memorySummary: String = ""
    var coachTone: CoachTone = .supportive
}

struct CoachMessageDTO: Sendable {
    let role: CoachRole
    let content: String
}

struct CoachResponse: Sendable {
    let content: String
    let tokenCount: Int
    let usedOpenAIAPI: Bool
}

// MARK: - Hybrid AI: on-device fallback + optional OpenAI Responses API

final class AIService: AIServiceProtocol, @unchecked Sendable {
    private let keychain: KeychainService
    private let openAIEndpoint = "https://api.openai.com/v1/responses"
    // Peak Coach is a conversational, latency-sensitive path. Terra preserves
    // the previous mini-model role while using the current GPT-5.6 family.
    private let openAIModel = "gpt-5.6-terra"

    var systemPrompt: String {
        """
        You are Peak Coach, a warm, evidence-aware wellness coach inside the Peak health app.

        Help the user understand recovery, sleep, hydration, nutrition, activity, mood, and sustainable habits using only the supplied context. State the most useful answer first, use short sections or bullets when they improve clarity, and ask at most one helpful follow-up question.

        Adapt suggestions to the user's explicitly selected daily status (Normal, Injured, Sick, Resting, or Traveling). When cycle context is supplied, personalize sleep, recovery, training, hydration, and habit suggestions without presenting phase estimates as fertility or pregnancy predictions. Never diagnose, prescribe treatment, or claim to replace a clinician. For symptoms, injury, medication, disordered eating, menstrual concerns, pregnancy concerns, or mental-health risk, recommend appropriate professional help. Do not infer medical conditions from scores. End health recommendations with: "This is wellness guidance, not medical advice."
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
        let fullSystem = systemPrompt
            + "\n\nCOACH STYLE:\n" + context.coachTone.instruction
            + "\n\nUSER CONTEXT:\n" + contextBlock

        // Cloud coaching is explicit opt-in because the context can contain health data.
        if context.allowsOpenAI,
           let apiKey = keychain.read(for: .openAIAPIKey),
           !apiKey.isEmpty {
            do {
                let response = try await callOpenAI(
                    apiKey: apiKey,
                    instructions: fullSystem,
                    history: history,
                    userMessage: message
                )
                await recordUsage(modelContext: modelContext, tokens: response.tokenCount)
                return response
            } catch {
                PeakLogger.ai.warning("OpenAI API failed, falling back to on-device: \(error.localizedDescription)")
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
        if context.cycleTrackingEnabled {
            chips.insert("Help me plan around my cycle", at: 1)
        }
        return Array(chips.prefix(4))
    }

    func analyzeMeal(_ analysisRequest: MealAnalysisRequest) async throws -> MealAnalysisResult {
        guard let apiKey = keychain.read(for: .openAIAPIKey), !apiKey.isEmpty else {
            throw PeakError.invalidInput("Add your OpenAI API key in Settings to use AI meal analysis.")
        }

        let prompt = """
        Analyze this meal for a wellness food log. Identify each visible or described food separately. Estimate the most likely edible serving, calories, protein, carbohydrates, total fat, saturated fat, fiber, sugar, sodium, cholesterol, and likely ingredients for that serving. Use ordinary food names, not medical claims. Be conservative when portions are unclear and lower confidence rather than inventing precision. Nutrition values are estimates that the user will review and edit before saving.

        User description: \(analysisRequest.query?.trimmed.isEmpty == false ? analysisRequest.query!.trimmed : "No additional description")
        """
        var content: [[String: Any]] = [["type": "input_text", "text": prompt]]
        if let imageData = analysisRequest.imageData {
            content.append([
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,\(imageData.base64EncodedString())",
                "detail": "high",
            ])
        }

        let itemSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "name": ["type": "string"],
                "serving": ["type": "string"],
                "calories": ["type": "integer", "minimum": 0],
                "protein_g": ["type": "number", "minimum": 0],
                "carbs_g": ["type": "number", "minimum": 0],
                "fat_g": ["type": "number", "minimum": 0],
                "fiber_g": ["type": "number", "minimum": 0],
                "sugar_g": ["type": "number", "minimum": 0],
                "saturated_fat_g": ["type": "number", "minimum": 0],
                "sodium_mg": ["type": "number", "minimum": 0],
                "cholesterol_mg": ["type": "number", "minimum": 0],
                "ingredients": ["type": "array", "items": ["type": "string"], "maxItems": 24],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
            ],
            "required": [
                "name", "serving", "calories", "protein_g", "carbs_g", "fat_g",
                "fiber_g", "sugar_g", "saturated_fat_g", "sodium_mg",
                "cholesterol_mg", "ingredients", "confidence",
            ],
        ]
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "overview": ["type": "string"],
                "items": ["type": "array", "minItems": 1, "maxItems": 12, "items": itemSchema],
            ],
            "required": ["title", "overview", "items"],
        ]
        var body: [String: Any] = [
            "model": "gpt-5.6-terra",
            "instructions": "Return a careful, editable meal estimate. Complete the requested schema and nothing else.",
            "input": [["role": "user", "content": content]],
            "reasoning": ["effort": "low"],
            "max_output_tokens": 1200,
            "text": [
                "verbosity": "low",
                "format": [
                    "type": "json_schema",
                    "name": "peak_meal_analysis",
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "store": false,
        ]
        if let safetyIdentifier { body["safety_identifier"] = safetyIdentifier }

        var request = URLRequest(url: URL(string: openAIEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PeakError.aiServiceUnavailable
        }

        struct ResponseEnvelope: Decodable {
            struct Output: Decodable {
                struct Content: Decodable { let type: String; let text: String? }
                let type: String
                let content: [Content]?
            }
            let output: [Output]
        }
        struct MealDTO: Decodable {
            struct Item: Decodable {
                let name: String
                let serving: String
                let calories: Int
                let protein_g: Double
                let carbs_g: Double
                let fat_g: Double
                let fiber_g: Double
                let sugar_g: Double
                let saturated_fat_g: Double
                let sodium_mg: Double
                let cholesterol_mg: Double
                let ingredients: [String]
                let confidence: Double
            }
            let title: String
            let overview: String
            let items: [Item]
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let outputText = envelope.output
            .filter({ $0.type == "message" })
            .flatMap({ $0.content ?? [] })
            .first(where: { $0.type == "output_text" })?.text,
              let outputData = outputText.data(using: .utf8) else {
            throw PeakError.aiServiceUnavailable
        }
        let decoded = try JSONDecoder().decode(MealDTO.self, from: outputData)
        return MealAnalysisResult(
            title: decoded.title,
            overview: decoded.overview,
            items: decoded.items.map {
                MealAnalysisItem(
                    name: $0.name,
                    serving: $0.serving,
                    calories: $0.calories,
                    proteinG: $0.protein_g,
                    carbsG: $0.carbs_g,
                    fatG: $0.fat_g,
                    fiberG: $0.fiber_g,
                    sugarG: $0.sugar_g,
                    saturatedFatG: $0.saturated_fat_g,
                    sodiumMg: $0.sodium_mg,
                    cholesterolMg: $0.cholesterol_mg,
                    ingredients: $0.ingredients,
                    confidence: $0.confidence
                )
            },
            source: analysisRequest.source
        )
    }

    // MARK: - OpenAI Responses API

    private func callOpenAI(
        apiKey: String,
        instructions: String,
        history: [CoachMessageDTO],
        userMessage: String
    ) async throws -> CoachResponse {
        var messages: [[String: String]] = []
        for msg in history.suffix(10) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        messages.append(["role": "user", "content": userMessage])

        var body: [String: Any] = [
            "model": openAIModel,
            "instructions": instructions,
            "input": messages,
            "max_output_tokens": 900,
            "reasoning": ["effort": "low"],
            "text": ["verbosity": "medium"],
            "store": false,
        ]
        if let safetyIdentifier { body["safety_identifier"] = safetyIdentifier }

        var request = URLRequest(url: URL(string: openAIEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PeakError.aiServiceUnavailable
        }

        struct OpenAIResponse: Decodable {
            struct Output: Decodable {
                struct Content: Decodable {
                    let type: String
                    let text: String?
                }
                let type: String
                let content: [Content]?
            }
            struct Usage: Decodable { let total_tokens: Int? }
            let output: [Output]
            let usage: Usage?
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = decoded.output
            .filter { $0.type == "message" }
            .flatMap { $0.content ?? [] }
            .first { $0.type == "output_text" }?
            .text ?? "I'm here to help. Could you rephrase that?"
        let tokens = decoded.usage?.total_tokens ?? content.count / 4

        let disclaimer = "This is wellness guidance, not medical advice."
        let finalContent = content.localizedCaseInsensitiveContains(disclaimer)
            ? content
            : content + "\n\n_\(disclaimer)_"
        return CoachResponse(content: finalContent, tokenCount: tokens, usedOpenAIAPI: true)
    }

    private var safetyIdentifier: String? {
        guard let userID = keychain.read(for: .currentUserID), !userID.isEmpty else { return nil }
        return SHA256.hash(data: Data(userID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - On-Device Fallback

    private func generateOnDeviceResponse(message: String, context: CoachContext) -> CoachResponse {
        let lower = message.lowercased()
        var response: String

        if context.cycleTrackingEnabled && (lower.contains("cycle") || lower.contains("period") || lower.contains("cramp")) {
            response = """
            **Cycle-aware check-in**

            \(context.cycleSummary.isEmpty ? "Keep logging cycle days and symptoms so patterns become clearer." : context.cycleSummary)

            Gentle movement, comfortable heat, adequate sleep, and symptom tracking may help some people manage period discomfort. Adjust activity to how you feel today, especially with your **\(context.wellnessStatus)** status. Seek clinical care for severe or worsening pain, very heavy bleeding, fainting, or symptoms that interrupt normal activities.

            _This is wellness guidance, not medical advice._
            """
        } else if lower.contains("recovery") || lower.contains("score") {
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

        return CoachResponse(content: response, tokenCount: response.count / 4, usedOpenAIAPI: false)
    }

    private func buildContextBlock(_ context: CoachContext) -> String {
        """
        Name: \(context.displayName)
        Selected date: \(context.selectedDate)
        Recovery: \(context.todayRecoveryScore) (\(context.recoveryLabel))
        Sleep: \(context.sleepHours)h
        Hydration: \(Int(context.hydrationPercent * 100))%
        Habits: \(context.habitsCompleted)/\(context.habitsTotal)
        Mood: \(context.moodRating > 0 ? "\(context.moodRating)/5" : "not logged")
        Goals: \(context.goals)
        Trend: \(context.recentTrend)
        Selected daily status: \(context.wellnessStatus)
        Cycle tracking enabled: \(context.cycleTrackingEnabled)
        Cycle context: \(context.cycleSummary.isEmpty ? "not supplied" : context.cycleSummary)
        Selected-day detail: \(context.daySummary.isEmpty ? "not available" : context.daySummary)
        Recent-day pattern summary: \(context.recentDataSummary.isEmpty ? "not available" : context.recentDataSummary)
        User-approved conversation memory: \(context.memorySummary.isEmpty ? "off or not available" : context.memorySummary)
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
