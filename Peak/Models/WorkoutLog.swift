import Foundation
import SwiftData

// MARK: - Workout Log (manual + HealthKit-synced)

@Model
final class WorkoutLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var name: String = ""
    var workoutType: String = "other" // WorkoutType raw value
    var durationMinutes: Double = 0
    var caloriesBurned: Double = 0
    var distanceKm: Double = 0
    var avgHeartRate: Double = 0
    var intensity: String = "moderate" // low, moderate, high
    var exerciseDetails: String = ""
    var note: String? = nil
    var isFromHealthKit: Bool = false
    var healthKitUUID: String? = nil
    var createdAt: Date = Date()

    init(
        name: String,
        workoutType: WorkoutType,
        durationMinutes: Double,
        caloriesBurned: Double = 0,
        distanceKm: Double = 0,
        avgHeartRate: Double = 0,
        intensity: WorkoutIntensity = .moderate,
        exerciseDetails: String = "",
        note: String? = nil,
        isFromHealthKit: Bool = false,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.name = name
        self.workoutType = workoutType.rawValue
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceKm = distanceKm
        self.avgHeartRate = avgHeartRate
        self.intensity = intensity.rawValue
        self.exerciseDetails = exerciseDetails
        self.note = note
        self.isFromHealthKit = isFromHealthKit
        self.createdAt = Date()
    }

    var type: WorkoutType { WorkoutType(rawValue: workoutType) ?? .other }
    var workoutIntensity: WorkoutIntensity { WorkoutIntensity(rawValue: intensity) ?? .moderate }
}

/// Lightweight, portable training templates. They intentionally live outside
/// SwiftData so users can create and edit programming without changing the
/// CloudKit health-data schema.
struct TrainingTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var workoutType: WorkoutType
    var durationMinutes: Double
    var intensity: WorkoutIntensity
    var exerciseDetails: String
    var note: String

    static let starter: [TrainingTemplate] = [
        TrainingTemplate(
            name: "Full Body Strength",
            workoutType: .strength,
            durationMinutes: 45,
            intensity: .moderate,
            exerciseDetails: "Squat · 3 × 8\nBench press · 3 × 8\nRow · 3 × 10\nRomanian deadlift · 3 × 8\nPlank · 3 × 45 sec",
            note: "Rest 90–120 seconds between working sets."
        ),
        TrainingTemplate(
            name: "Zone 2 Cardio",
            workoutType: .cycling,
            durationMinutes: 40,
            intensity: .low,
            exerciseDetails: "5 min easy warm-up\n30 min conversational pace\n5 min easy cool-down",
            note: "Keep the effort controlled and sustainable."
        ),
    ]
}

enum TrainingTemplateStore {
    static let key = "peak.training.templates.v1"

    static func load(from data: Data) -> [TrainingTemplate] {
        guard !data.isEmpty,
              let templates = try? JSONDecoder().decode([TrainingTemplate].self, from: data) else {
            return TrainingTemplate.starter
        }
        return templates
    }

    static func encode(_ templates: [TrainingTemplate]) -> Data {
        (try? JSONEncoder().encode(templates)) ?? Data()
    }
}

enum WorkoutType: String, CaseIterable, Codable, Identifiable, Hashable {
    case running, walking, cycling, strength, yoga, swimming, hiit, pilates, stretching, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hiit: return "HIIT"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        case .swimming: return "figure.pool.swim"
        case .hiit: return "bolt.heart.fill"
        case .pilates: return "figure.pilates"
        case .stretching: return "figure.flexibility"
        case .other: return "figure.mixed.cardio"
        }
    }

    var color: String {
        switch self {
        case .running: return "FF6B6B"
        case .walking: return "4ECDC4"
        case .cycling: return "45B7D1"
        case .strength: return "6C5CE7"
        case .yoga: return "A29BFE"
        case .swimming: return "74B9FF"
        case .hiit: return "FD79A8"
        case .pilates: return "FDCB6E"
        case .stretching: return "00B894"
        case .other: return "636E72"
        }
    }

    /// Estimated kcal/min for moderate intensity
    var kcalPerMinute: Double {
        switch self {
        case .running: return 11
        case .walking: return 4
        case .cycling: return 8
        case .strength: return 6
        case .yoga: return 3
        case .swimming: return 9
        case .hiit: return 12
        case .pilates: return 4
        case .stretching: return 2
        case .other: return 5
        }
    }
}

enum WorkoutIntensity: String, CaseIterable, Codable, Hashable {
    case low, moderate, high

    var displayName: String { rawValue.capitalized }
    var multiplier: Double {
        switch self {
        case .low: return 0.7
        case .moderate: return 1.0
        case .high: return 1.3
        }
    }
}
