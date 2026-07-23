import Foundation
import SwiftData

// MARK: - Hydration Log

@Model
final class HydrationLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var amountML: Int = 0
    var beverageType: String = "water" // BeverageType raw value
    var note: String? = nil
    var createdAt: Date = Date()

    init(amountML: Int, beverageType: BeverageType = .water, date: Date = Date(), note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.amountML = amountML
        self.beverageType = beverageType.rawValue
        self.note = note
        self.createdAt = Date()
    }

    var beverage: BeverageType { BeverageType(rawValue: beverageType) ?? .water }
}

enum BeverageType: String, CaseIterable, Codable, Identifiable {
    case water, coffee, tea, sports, smoothie, other

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .tea: return "leaf.fill"
        case .sports: return "bolt.fill"
        case .smoothie: return "blender.fill"
        case .other: return "mug.fill"
        }
    }

    var defaultML: Int {
        switch self {
        case .water: return 250
        case .coffee, .tea: return 200
        case .sports: return 500
        case .smoothie: return 350
        case .other: return 250
        }
    }
}

struct HydrationLogExport: Codable {
    let date: Date
    let amountML: Int
    let note: String?
}
