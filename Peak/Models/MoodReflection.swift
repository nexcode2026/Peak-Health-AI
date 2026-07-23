import Foundation
import SwiftData

// MARK: - Mood & Reflection Entry

@Model
final class MoodReflection {
    var id: UUID = UUID()
    var date: Date = Date()
    var moodRating: Int = 3 // 1-5
    var energyLevel: Int = 3 // 1-5
    var note: String? = nil
    /// JSON-encoded `[String]` — CloudKit-safe (primitive arrays are not supported).
    var tagsJSON: String = "[]"
    var photoAssetIdentifier: String? = nil
    var photoLocalPath: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var journalEntry: JournalEntry? = nil

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
        self.tagsJSON = Self.encodeTags(tags)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    @Transient
    var tags: [String] {
        get { Self.decodeTags(tagsJSON) }
        set { tagsJSON = Self.encodeTags(newValue) }
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

    private static func encodeTags(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeTags(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
}

struct MoodReflectionExport: Codable {
    let date: Date
    let moodRating: Int
    let energyLevel: Int
    let note: String?
    let tags: [String]
}
