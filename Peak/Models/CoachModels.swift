import Foundation
import SwiftData

// MARK: - AI Coach Conversation

@Model
final class CoachConversation {
    var id: UUID = UUID()
    var title: String = "New Conversation"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CoachMessage.conversation)
    var messages: [CoachMessage]? = []

    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }
}

@Model
final class CoachMessage {
    var id: UUID = UUID()
    var role: String = "user" // "user", "assistant", "system"
    var content: String = ""
    var createdAt: Date = Date()
    var tokenCount: Int = 0
    var conversation: CoachConversation? = nil

    init(role: CoachRole, content: String, tokenCount: Int = 0) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.tokenCount = tokenCount
    }

    var coachRole: CoachRole {
        CoachRole(rawValue: role) ?? .user
    }
}

enum CoachRole: String, Codable {
    case user
    case assistant
    case system
}

enum CoachTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case supportive
    case concise
    case analytical
    case motivating

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var instruction: String {
        switch self {
        case .supportive: "Be warm, calm, encouraging, and practical."
        case .concise: "Be brief and direct. Prefer compact answers and clear next actions."
        case .analytical: "Explain patterns, contributing signals, uncertainty, and tradeoffs."
        case .motivating: "Use energetic, positive language and turn recommendations into achievable challenges."
        }
    }
}

// MARK: - AI Usage Tracking

@Model
final class AIUsageRecord {
    var id: UUID = UUID()
    var month: String = "" // "2026-06"
    var messageCount: Int = 0
    var tokenCount: Int = 0
    var lastUpdated: Date = Date()

    init(month: String = AIUsageRecord.currentMonth) {
        self.id = UUID()
        self.month = month
        self.messageCount = 0
        self.tokenCount = 0
        self.lastUpdated = Date()
    }

    static var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
