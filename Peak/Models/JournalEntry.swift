import Foundation
import SwiftData

// MARK: - Journal Entry (extended reflections)

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String? = nil
    var body: String = ""
    @Relationship(deleteRule: .nullify, inverse: \MoodReflection.journalEntry)
    var moodReflection: MoodReflection? = nil
    var photoAssetIdentifier: String? = nil
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
