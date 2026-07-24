import Foundation
import SwiftData

// MARK: - Food & Nutrition Log

@Model
final class FoodLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var name: String = ""
    var mealType: String = "snack" // MealType raw value
    var calories: Int = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var fiberG: Double = 0
    var sugarG: Double = 0
    var saturatedFatG: Double = 0
    var sodiumMg: Double = 0
    var cholesterolMg: Double = 0
    var servingSize: String? = nil
    var ingredients: String = ""
    var note: String? = nil
    var createdAt: Date = Date()

    init(
        name: String,
        mealType: MealType = .snack,
        calories: Int = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        sugarG: Double = 0,
        saturatedFatG: Double = 0,
        sodiumMg: Double = 0,
        cholesterolMg: Double = 0,
        servingSize: String? = nil,
        ingredients: String = "",
        note: String? = nil,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.name = name
        self.mealType = mealType.rawValue
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.saturatedFatG = saturatedFatG
        self.sodiumMg = sodiumMg
        self.cholesterolMg = cholesterolMg
        self.servingSize = servingSize
        self.ingredients = ingredients
        self.note = note
        self.createdAt = Date()
    }

    var meal: MealType { MealType(rawValue: mealType) ?? .snack }
}

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "carrot.fill"
        }
    }

    var color: String {
        switch self {
        case .breakfast: return "F5A623"
        case .lunch: return "4ECDC4"
        case .dinner: return "6C5CE7"
        case .snack: return "FF6B6B"
        }
    }
}

/// Quick-add food presets
enum FoodPresets {
    static let common: [(name: String, cal: Int, protein: Double, carbs: Double, fat: Double)] = [
        ("Protein Shake", 180, 30, 8, 3),
        ("Greek Yogurt", 150, 15, 12, 4),
        ("Chicken Breast", 230, 43, 0, 5),
        ("Oatmeal Bowl", 280, 10, 48, 6),
        ("Salad", 120, 4, 14, 6),
        ("Banana", 105, 1, 27, 0),
        ("Eggs (2)", 140, 12, 1, 10),
        ("Rice Bowl", 320, 6, 68, 2),
    ]
}
