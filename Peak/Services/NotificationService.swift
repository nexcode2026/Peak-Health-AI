import Foundation
import UserNotifications

// MARK: - Notification Service Protocol

protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func configure(profile: UserProfile)
    func scheduleHabitReminder(hour: Int)
    func scheduleHydrationReminders(intervalHours: Int)
    func scheduleWindDownReminder(hour: Int)
    func scheduleStreakCelebration(streakDays: Int)
    func cancelAll()
    var isAuthorized: Bool { get }
}

// MARK: - Local + Remote-Capable Notifications

final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()
    private(set) var isAuthorized: Bool = false

    enum Category: String {
        case habit = "HABIT_REMINDER"
        case hydration = "HYDRATION_REMINDER"
        case windDown = "WIND_DOWN"
        case insight = "DAILY_INSIGHT"
        case streak = "STREAK_CELEBRATION"
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted { await registerCategories() }
            return granted
        } catch {
            PeakLogger.general.error("Notification auth failed: \(error.localizedDescription)")
            return false
        }
    }

    func configure(profile: UserProfile) {
        guard profile.notificationsEnabled else {
            cancelAll()
            return
        }
        scheduleHabitReminder(hour: profile.habitReminderHour)
        scheduleHydrationReminders(intervalHours: profile.hydrationReminderIntervalHours)
        scheduleWindDownReminder(hour: profile.windDownReminderHour)
    }

    func scheduleHabitReminder(hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time for your habits"
        content.body = "A few micro-habits today compounds into peak performance."
        content.sound = .default
        content.categoryIdentifier = Category.habit.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "habit-daily", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleHydrationReminders(intervalHours: Int) {
        let hours = [8, 8 + intervalHours, 8 + intervalHours * 2, 8 + intervalHours * 3].filter { $0 < 22 }
        for (index, hour) in hours.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Stay hydrated"
            content.body = "Tap +1 glass in Peak to log your water intake."
            content.sound = .default
            content.categoryIdentifier = Category.hydration.rawValue

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "hydration-\(index)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    func scheduleWindDownReminder(hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Wind-down time"
        content.body = "Start your evening routine for better recovery tonight."
        content.sound = .default
        content.categoryIdentifier = Category.windDown.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "wind-down", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleStreakCelebration(streakDays: Int) {
        guard streakDays > 0, streakDays % 7 == 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streakDays)-day streak!"
        content.body = "You're building real momentum. Keep it going!"
        content.sound = .default
        content.categoryIdentifier = Category.streak.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak-\(streakDays)", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func registerCategories() async {
        let habitAction = UNNotificationAction(identifier: "LOG_HABIT", title: "Log Habits", options: .foreground)
        let waterAction = UNNotificationAction(identifier: "LOG_WATER", title: "+1 Glass", options: .foreground)

        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: Category.habit.rawValue, actions: [habitAction], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.hydration.rawValue, actions: [waterAction], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.windDown.rawValue, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.insight.rawValue, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.streak.rawValue, actions: [], intentIdentifiers: []),
        ]
        center.setNotificationCategories(categories)
    }
}