import Foundation
import SwiftData

// MARK: - AI Coach Conversation

@Model
final class CoachConversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CoachMessage.conversation)
    var messages: [CoachMessage]

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
    var id: UUID
    var role: String // "user", "assistant", "system"
    var content: String
    var createdAt: Date
    var tokenCount: Int
    var conversation: CoachConversation?

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

// MARK: - AI Usage Tracking

@Model
final class AIUsageRecord {
    var id: UUID
    var month: String // "2026-06"
    var messageCount: Int
    var tokenCount: Int
    var lastUpdated: Date

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