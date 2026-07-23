import Foundation
import SwiftData

// MARK: - Journal Entry (extended reflections)

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var title: String?
    var body: String
    @Relationship(inverse: \MoodReflection.journalEntry)
    var moodReflection: MoodReflection?
    var photoAssetIdentifier: String?
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(title: String? = nil, body: String, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.body = body
        self.isPinned = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}