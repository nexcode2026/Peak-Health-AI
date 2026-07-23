import Foundation

// MARK: - App Constants

enum PeakConstants {
    static let appName = "Peak"
    static let bundleIdentifier = "com.peak.health"
    // Must exactly match Peak.entitlements and the App ID's provisioning profile.
    static let cloudKitContainer = "iCloud.com.nexcode.peak.health"
    static let minimumIOSVersion = "18.0"

    // MARK: - Recovery Scoring Weights (documented assumptions)
    // Composite score 0–100. Weights sum to 1.0.
    enum RecoveryWeights {
        static let sleep: Double = 0.30
        static let hrvRestingHR: Double = 0.25
        static let activityBalance: Double = 0.15
        static let hydration: Double = 0.10
        static let mood: Double = 0.10
        static let habits: Double = 0.10
    }

    // MARK: - Default Goals
    enum Defaults {
        static let dailyWaterML: Int = 2500
        static let sleepHoursTarget: Double = 8.0
        static let recoveryTarget: Int = 75
        static let dailyStepsGoal: Int = 10_000
        static let habitGlassML: Int = 250
        static let dailyCalorieGoal: Int = 2200
        static let dailyProteinGoalG: Int = 120
        static let weeklyWorkoutGoal: Int = 4
        static let dailyActiveMinutesGoal: Int = 30
        static let restingHRTarget: Int = 60
    }

    // MARK: - Subscription Product IDs
    enum Products {
        static let premiumWeekly = "com.peak.premium.weekly"
        static let premiumMonthly = "com.peak.premium.monthly"
        static let premiumYearly = "com.peak.premium.yearly"
        static let all = [premiumWeekly, premiumMonthly, premiumYearly]
    }

    // MARK: - Free Tier Limits
    enum FreeTierLimits {
        static let maxHabits = 3
        static let maxAIMessagesPerMonth = 10
        static let historyDays = 14
        static let maxCoachConversations = 1
    }

    // MARK: - Premium Limits
    enum PremiumLimits {
        static let maxAIMessagesPerMonth = 500
    }

    // MARK: - Pro Limits
    enum ProLimits {
        static let maxAIMessagesPerMonth = 2000
    }

    // MARK: - URLs (placeholders for App Store submission)
    enum URLs {
        static let privacyPolicy = "https://peak-health.app/privacy"
        static let termsOfService = "https://peak-health.app/terms"
        static let support = "https://peak-health.app/support"
        static let roadmap = "https://peak-health.app/roadmap"
    }

    // MARK: - Medical Disclaimer
    static let medicalDisclaimer =
        "Peak is a wellness tool, not a medical device. It does not diagnose, treat, or prevent any condition. Always consult a qualified healthcare professional for medical advice."

    // MARK: - AI Coach System Prompt (excerpt; full prompt in AIService)
    static let coachPersonaName = "Peak Coach"
}
