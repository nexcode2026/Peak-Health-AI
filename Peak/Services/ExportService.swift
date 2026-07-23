import Foundation
import PDFKit
import SwiftUI
import SwiftData

// MARK: - Export Service Protocol

protocol ExportServiceProtocol: Sendable {
    func exportCSV(modelContext: ModelContext) throws -> URL
    func exportPDF(modelContext: ModelContext, profile: UserProfile) throws -> URL
}

// MARK: - CSV + PDF Export

final class ExportService: ExportServiceProtocol {
    func exportCSV(modelContext: ModelContext) throws -> URL {
        var lines: [String] = ["type,date,value,detail"]

        let scores = try modelContext.fetch(FetchDescriptor<RecoveryScore>(sortBy: [SortDescriptor(\.date)]))
        for score in scores {
            lines.append("recovery,\(score.date.ISO8601Format()),\(score.overallScore),\"\(score.explanation.replacingOccurrences(of: "\"", with: "'"))\"")
        }

        let hydration = try modelContext.fetch(FetchDescriptor<HydrationLog>(sortBy: [SortDescriptor(\.date)]))
        for log in hydration {
            lines.append("hydration,\(log.date.ISO8601Format()),\(log.amountML),")
        }

        let moods = try modelContext.fetch(FetchDescriptor<MoodReflection>(sortBy: [SortDescriptor(\.date)]))
        for mood in moods {
            lines.append("mood,\(mood.date.ISO8601Format()),\(mood.moodRating),\"\(mood.note ?? "")\"")
        }

        let habitLogs = try modelContext.fetch(FetchDescriptor<HabitLog>(sortBy: [SortDescriptor(\.date)]))
        for log in habitLogs {
            let name = log.habit?.name ?? "unknown"
            lines.append("habit,\(log.date.ISO8601Format()),\(log.completed ? 1 : 0),\(name)")
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peak-export-\(Date().formatted(date: .numeric, time: .omitted)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportPDF(modelContext: ModelContext, profile: UserProfile) throws -> URL {
        let scores = try modelContext.fetch(
            FetchDescriptor<RecoveryScore>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        ).prefix(30)

        let avgScore = scores.isEmpty ? 0 : scores.map(\.overallScore).reduce(0, +) / scores.count

        let pdfMeta = [
            kCGPDFContextCreator: "Peak Health App",
            kCGPDFContextTitle: "Peak Recovery Report",
        ]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peak-report-\(Date().formatted(date: .numeric, time: .omitted)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.1, green: 0.4, blue: 0.45, alpha: 1),
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray,
            ]

            "Peak Recovery Report".draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)
            "Generated for \(profile.displayName) · \(Date().formatted(date: .long, time: .omitted))".draw(
                at: CGPoint(x: 40, y: 80), withAttributes: bodyAttrs
            )

            "30-Day Average Recovery: \(avgScore)".draw(at: CGPoint(x: 40, y: 120), withAttributes: bodyAttrs)

            var y: CGFloat = 160
            for score in scores {
                let line = "\(score.date.formatted(date: .abbreviated, time: .omitted)): \(score.overallScore) — \(PeakTheme.recoveryLabel(for: score.overallScore))"
                line.draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
                y += 22
                if y > 720 { break }
            }

            PeakConstants.medicalDisclaimer.draw(
                in: CGRect(x: 40, y: 720, width: 532, height: 60),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
            )
        }

        return url
    }
}