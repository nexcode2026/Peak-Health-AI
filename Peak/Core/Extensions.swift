import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var formattedShort: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var formattedTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    var dayOfWeekShort: String {
        formatted(.dateTime.weekday(.abbreviated))
    }
}

// MARK: - Double Extensions

extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Int Extensions

extension Int {
    var formattedScore: String { "\(self)" }

    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - String Extensions

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNotEmpty: Bool { !isEmpty }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - View Extensions

extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}