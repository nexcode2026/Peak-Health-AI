import Foundation
import SwiftData

// MARK: - User Profile (SwiftData + CloudKit sync)

@Model
final class UserProfile {
    var id: UUID
    var appleUserID: String
    var displayName: String
    var email: String?
    var avatarData: Data?
    var createdAt: Date
    var updatedAt: Date

    // Goals
    var recoveryTarget: Int
    var dailyWaterGoalML: Int
    var sleepHoursTarget: Double
    var dailyStepsGoal: Int

    // Preferences
    var faceIDEnabled: Bool
    var notificationsEnabled: Bool
    var darkModePreference: String // "system", "light", "dark"
    var useGrokAPI: Bool
    var onboardingCompleted: Bool
    var sampleDataLoaded: Bool

    // Notification preferences
    var habitReminderHour: Int
    var hydrationReminderIntervalHours: Int
    var windDownReminderHour: Int

    @Relationship(deleteRule: .cascade, inverse: \HabitDefinition.owner)
    var habits: [HabitDefinition]

    init(
        appleUserID: String,
        displayName: String = "Peak User",
        email: String? = nil
    ) {
        self.id = UUID()
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recoveryTarget = PeakConstants.Defaults.recoveryTarget
        self.dailyWaterGoalML = PeakConstants.Defaults.dailyWaterML
        self.sleepHoursTarget = PeakConstants.Defaults.sleepHoursTarget
        self.dailyStepsGoal = PeakConstants.Defaults.dailyStepsGoal
        self.faceIDEnabled = false
        self.notificationsEnabled = true
        self.darkModePreference = "system"
        self.useGrokAPI = false
        self.onboardingCompleted = false
        self.sampleDataLoaded = false
        self.habitReminderHour = 8
        self.hydrationReminderIntervalHours = 2
        self.windDownReminderHour = 21
        self.habits = []
    }
}

// MARK: - Codable Export DTO

struct UserProfileExport: Codable {
    let id: UUID
    let displayName: String
    let recoveryTarget: Int
    let dailyWaterGoalML: Int
    let sleepHoursTarget: Double
    let createdAt: Date
}