import Foundation
import SwiftData

// MARK: - User Profile (SwiftData + CloudKit sync)

@Model
final class UserProfile {
    var id: UUID = UUID()
    var appleUserID: String = ""
    var displayName: String = "Peak User"
    var email: String? = nil
    @Attribute(.externalStorage) var avatarData: Data? = nil
    var bio: String? = nil
    var dateOfBirth: Date? = nil
    var heightCm: Double = 0
    var weightKg: Double = 0
    var gender: String = "preferNotToSay" // GenderOption raw value
    var activityLevel: String = "moderate" // ActivityLevel raw value
    var preferredUnits: String = "metric" // "metric" or "imperial"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Goals
    var recoveryTarget: Int = 75
    var dailyWaterGoalML: Int = 2500
    var sleepHoursTarget: Double = 8
    var dailyStepsGoal: Int = 10_000
    var dailyCalorieGoal: Int = 2200
    var dailyProteinGoalG: Int = 120
    var weeklyWorkoutGoal: Int = 4
    var dailyActiveMinutesGoal: Int = 30
    var restingHRTarget: Int = 60

    // Preferences
    var faceIDEnabled: Bool = false
    var notificationsEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var darkModePreference: String = "system" // "system", "light", "dark"
    /// Legacy storage name retained so existing SwiftData/iCloud stores migrate safely.
    /// The product-facing feature is now OpenAI-backed.
    var useGrokAPI: Bool = false
    var showHealthMetrics: Bool = true
    var autoSyncHealthKit: Bool = true
    var onboardingCompleted: Bool = false
    var sampleDataLoaded: Bool = false
    var currentWellnessStatus: String = WellnessStatus.normal.rawValue
    var todayMetricLayout: String = TodayMetricLayout.detailed.rawValue
    var healthMetricLayout: String = TodayMetricLayout.compact.rawValue
    var todaySectionOrder: String = TodaySection.defaultOrder.map(\.rawValue).joined(separator: ",")
    var todayHiddenSections: String = ""
    var todayHealthMetricOrder: String = HealthMetricType.allCases.map(\.rawValue).joined(separator: ",")
    var todayHiddenHealthMetrics: String = ""
    var cycleTrackingEnabled: Bool = false
    var averageCycleLength: Int = 28
    var averagePeriodLength: Int = 5

    // Notification preferences
    var habitReminderHour: Int = 8
    var hydrationReminderIntervalHours: Int = 2
    var windDownReminderHour: Int = 21
    var mealReminderEnabled: Bool = false
    var workoutReminderEnabled: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \HabitDefinition.owner)
    var habits: [HabitDefinition]? = []

    init(
        appleUserID: String,
        displayName: String = "Peak User",
        email: String? = nil
    ) {
        self.id = UUID()
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.bio = nil
        self.heightCm = 0
        self.weightKg = 0
        self.gender = GenderOption.preferNotToSay.rawValue
        self.activityLevel = ActivityLevel.moderate.rawValue
        self.preferredUnits = "metric"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recoveryTarget = PeakConstants.Defaults.recoveryTarget
        self.dailyWaterGoalML = PeakConstants.Defaults.dailyWaterML
        self.sleepHoursTarget = PeakConstants.Defaults.sleepHoursTarget
        self.dailyStepsGoal = PeakConstants.Defaults.dailyStepsGoal
        self.dailyCalorieGoal = PeakConstants.Defaults.dailyCalorieGoal
        self.dailyProteinGoalG = PeakConstants.Defaults.dailyProteinGoalG
        self.weeklyWorkoutGoal = PeakConstants.Defaults.weeklyWorkoutGoal
        self.dailyActiveMinutesGoal = PeakConstants.Defaults.dailyActiveMinutesGoal
        self.restingHRTarget = PeakConstants.Defaults.restingHRTarget
        self.faceIDEnabled = false
        self.notificationsEnabled = true
        self.hapticsEnabled = true
        self.darkModePreference = "system"
        self.useGrokAPI = false
        self.showHealthMetrics = true
        self.autoSyncHealthKit = true
        self.onboardingCompleted = false
        self.sampleDataLoaded = false
        self.currentWellnessStatus = WellnessStatus.normal.rawValue
        self.todayMetricLayout = TodayMetricLayout.detailed.rawValue
        self.healthMetricLayout = TodayMetricLayout.compact.rawValue
        self.todaySectionOrder = TodaySection.defaultOrder.map(\.rawValue).joined(separator: ",")
        self.todayHiddenSections = ""
        self.todayHealthMetricOrder = HealthMetricType.allCases.map(\.rawValue).joined(separator: ",")
        self.todayHiddenHealthMetrics = ""
        self.cycleTrackingEnabled = false
        self.averageCycleLength = 28
        self.averagePeriodLength = 5
        self.habitReminderHour = 8
        self.hydrationReminderIntervalHours = 2
        self.windDownReminderHour = 21
        self.mealReminderEnabled = false
        self.workoutReminderEnabled = true
        self.habits = []
    }

    var genderOption: GenderOption { GenderOption(rawValue: gender) ?? .preferNotToSay }
    var activity: ActivityLevel { ActivityLevel(rawValue: activityLevel) ?? .moderate }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var bmi: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    var useOpenAIAPI: Bool {
        get { useGrokAPI }
        set { useGrokAPI = newValue }
    }

    var wellnessStatus: WellnessStatus {
        WellnessStatus(rawValue: currentWellnessStatus) ?? .normal
    }

    var metricLayout: TodayMetricLayout {
        TodayMetricLayout(rawValue: todayMetricLayout) ?? .detailed
    }

    var healthLayout: TodayMetricLayout {
        TodayMetricLayout(rawValue: healthMetricLayout) ?? .compact
    }
}

enum WellnessStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal, injured, sick, resting, traveling

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .normal: "✨"
        case .injured: "🩹"
        case .sick: "🤒"
        case .resting: "🧘"
        case .traveling: "✈️"
        }
    }

    var guidance: String {
        switch self {
        case .normal: "Your usual goals and recommendations are active."
        case .injured: "Peak will favor recovery and low-impact suggestions."
        case .sick: "Rest, hydration, and symptom-aware guidance take priority."
        case .resting: "Training load is intentionally reduced today."
        case .traveling: "Sleep timing, hydration, and mobility get extra attention."
        }
    }
}

enum TodayMetricLayout: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact, detailed

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .compact: "Five condensed cards in a flexible grid"
        case .detailed: "Full gauges, factors, and supporting metrics"
        }
    }
}

enum TodaySection: String, CaseIterable, Identifiable, Codable, Sendable {
    case quickLog, plan, yourDay, health, cycle, habits, insight, achievements

    static let defaultOrder: [TodaySection] = [
        .plan, .yourDay, .health, .cycle, .habits, .insight, .achievements,
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickLog: "Quick Log"
        case .plan: "Peak Plan"
        case .yourDay: "Your Day"
        case .health: "Health Monitoring"
        case .cycle: "Cycle Tracking"
        case .habits: "Habits"
        case .insight: "Daily Insight"
        case .achievements: "Achievements"
        }
    }

    var icon: String {
        switch self {
        case .quickLog: "plus.circle.fill"
        case .plan: "checklist.checked"
        case .yourDay: "circle.hexagongrid.fill"
        case .health: "heart.text.square.fill"
        case .cycle: "calendar.circle.fill"
        case .habits: "checkmark.circle.fill"
        case .insight: "sparkles"
        case .achievements: "medal.fill"
        }
    }
}

enum HealthMetricType: String, CaseIterable, Identifiable, Codable, Sendable {
    case weight, heartRate, respiratoryRate, bloodPressure, bloodOxygen, height, restingHeartRate, temperature, sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .heartRate: "Heart Rate"
        case .respiratoryRate: "Respiratory Rate"
        case .bloodPressure: "Blood Pressure"
        case .bloodOxygen: "Blood Oxygen"
        case .height: "Height"
        case .restingHeartRate: "Resting Heart Rate"
        case .temperature: "Temperature"
        case .sleep: "Sleep"
        }
    }

    var shortTitle: String {
        switch self {
        case .respiratoryRate: "Respiration"
        case .bloodPressure: "Blood Pressure"
        case .bloodOxygen: "Oxygen"
        case .restingHeartRate: "Resting HR"
        default: title
        }
    }

    var icon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .heartRate: "heart.fill"
        case .respiratoryRate: "wind"
        case .bloodPressure: "waveform.path.ecg.rectangle.fill"
        case .bloodOxygen: "lungs.fill"
        case .height: "ruler.fill"
        case .restingHeartRate: "heart.circle.fill"
        case .temperature: "thermometer.medium"
        case .sleep: "moon.zzz.fill"
        }
    }
}

enum GenderOption: String, CaseIterable, Codable {
    case male, female, nonBinary, preferNotToSay

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .nonBinary: return "Non-binary"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary, light, moderate, active, athlete

    var displayName: String { rawValue.capitalized }

    var description: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "1–2 workouts per week"
        case .moderate: return "3–4 workouts per week"
        case .active: return "5–6 workouts per week"
        case .athlete: return "Daily intense training"
        }
    }

    var calorieMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .athlete: return 1.9
        }
    }
}

// MARK: - Private cycle log (SwiftData + CloudKit)

@Model
final class CycleEntry {
    var id: UUID = UUID()
    var date: Date = Date().startOfDay
    var isPeriodDay: Bool = false
    var flowLevel: String = CycleFlow.none.rawValue
    var symptomsCSV: String = ""
    var energy: Int = 3
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = .now,
        isPeriodDay: Bool = false,
        flow: CycleFlow = .none,
        symptoms: [CycleSymptom] = [],
        energy: Int = 3,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date.startOfDay
        self.isPeriodDay = isPeriodDay
        self.flowLevel = flow.rawValue
        self.symptomsCSV = symptoms.map(\.rawValue).joined(separator: ",")
        self.energy = energy
        self.notes = notes
        self.createdAt = .now
    }

    var flow: CycleFlow {
        get { CycleFlow(rawValue: flowLevel) ?? .none }
        set { flowLevel = newValue.rawValue }
    }

    var symptoms: [CycleSymptom] {
        get { symptomsCSV.split(separator: ",").compactMap { CycleSymptom(rawValue: String($0)) } }
        set { symptomsCSV = newValue.map(\.rawValue).joined(separator: ",") }
    }
}

enum CycleFlow: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, light, medium, heavy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CycleSymptom: String, CaseIterable, Identifiable, Codable, Sendable {
    case cramps, headache, bloating, fatigue, tenderness, moodChanges, cravings, nausea
    var id: String { rawValue }
    var title: String {
        switch self {
        case .moodChanges: "Mood changes"
        default: rawValue.capitalized
        }
    }
}

struct CycleTrackingSummary: Sendable {
    let cycleDay: Int?
    let phase: String
    let lastPeriodStart: Date?

    static func make(entries: [CycleEntry], averageCycleLength: Int, periodLength: Int) -> CycleTrackingSummary {
        let periodDays = Set(entries.filter(\.isPeriodDay).map { $0.date.startOfDay })
        let starts = periodDays.filter { day in
            let prior = Calendar.current.date(byAdding: .day, value: -1, to: day)?.startOfDay
            return prior.map { !periodDays.contains($0) } ?? true
        }.sorted(by: >)
        guard let start = starts.first else {
            return CycleTrackingSummary(cycleDay: nil, phase: "Not enough data", lastPeriodStart: nil)
        }
        let elapsed = max(0, Calendar.current.dateComponents([.day], from: start, to: Date().startOfDay).day ?? 0)
        let day = elapsed + 1
        let normalizedDay = ((day - 1) % max(21, averageCycleLength)) + 1
        let phase: String
        if normalizedDay <= max(2, periodLength) {
            phase = "Menstrual phase"
        } else if normalizedDay < max(8, averageCycleLength - 16) {
            phase = "Follicular phase estimate"
        } else if normalizedDay <= max(14, averageCycleLength - 12) {
            phase = "Ovulation window estimate"
        } else {
            phase = "Luteal phase estimate"
        }
        return CycleTrackingSummary(cycleDay: normalizedDay, phase: phase, lastPeriodStart: start)
    }
}
