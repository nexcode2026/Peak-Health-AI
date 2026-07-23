import Foundation
import SwiftData

// MARK: - Habit Definition

@Model
final class HabitDefinition {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var colorHex: String
    var isCustom: Bool
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date
    var owner: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]

    init(
        name: String,
        icon: String = "checkmark.circle",
        colorHex: String = "FF6B4A",
        isCustom: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isCustom = isCustom
        self.isActive = true
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.logs = []
    }
}

// MARK: - Habit Log Entry

@Model
final class HabitLog {
    var id: UUID
    var date: Date
    var completed: Bool
    var note: String?
    var createdAt: Date
    var habit: HabitDefinition?

    init(habit: HabitDefinition, date: Date = Date().startOfDay, completed: Bool = true, note: String? = nil) {
        self.id = UUID()
        self.date = date.startOfDay
        self.completed = completed
        self.note = note
        self.createdAt = Date()
        self.habit = habit
    }
}

// MARK: - Predefined Habits

enum PredefinedHabits {
    static let defaults: [(name: String, icon: String, color: String)] = [
        ("Morning Stretch", "figure.flexibility", "4ECDC4"),
        ("Meditation", "brain.head.profile", "6C5CE7"),
        ("Cold Exposure", "snowflake", "74B9FF"),
        ("Journal", "book.fill", "FDCB6E"),
        ("No Screens Before Bed", "moon.zzz.fill", "A29BFE"),
        ("Protein Breakfast", "fork.knife", "FF6B4A"),
        ("Walk 10 min", "figure.walk", "00B894"),
        ("Supplements", "pills.fill", "E17055"),
    ]
}

struct HabitLogExport: Codable {
    let habitName: String
    let date: Date
    let completed: Bool
    let note: String?
}