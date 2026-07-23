import Foundation
import SwiftData

// MARK: - Mood & Reflection Entry

@Model
final class MoodReflection {
    var id: UUID
    var date: Date
    var moodRating: Int // 1-5
    var energyLevel: Int // 1-5
    var note: String?
    var tags: [String]
    var photoAssetIdentifier: String? // CloudKit CKAsset reference
    var photoLocalPath: String?
    var createdAt: Date
    var updatedAt: Date

    var journalEntry: JournalEntry?

    init(
        moodRating: Int,
        energyLevel: Int = 3,
        note: String? = nil,
        tags: [String] = [],
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.moodRating = moodRating.clamped(to: 1...5)
        self.energyLevel = energyLevel.clamped(to: 1...5)
        self.note = note
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var moodEmoji: String {
        switch moodRating {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }
}

struct MoodReflectionExport: Codable {
    let date: Date
    let moodRating: Int
    let energyLevel: Int
    let note: String?
    let tags: [String]
}