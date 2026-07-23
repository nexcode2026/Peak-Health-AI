import Foundation
import SwiftData

// MARK: - Hydration Log

@Model
final class HydrationLog {
    var id: UUID
    var date: Date
    var amountML: Int
    var note: String?
    var createdAt: Date

    init(amountML: Int, date: Date = Date(), note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.amountML = amountML
        self.note = note
        self.createdAt = Date()
    }
}

struct HydrationLogExport: Codable {
    let date: Date
    let amountML: Int
    let note: String?
}