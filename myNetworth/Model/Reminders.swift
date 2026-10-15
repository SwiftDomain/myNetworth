//
//  Reminders.swift
//  myNetworth
//

import Foundation
import Observation
import UserNotifications

// MARK: - Balance Reminder

/// The monthly notification that asks the user to update their balances. It's off until
/// turned on in Settings, which is when iOS asks for permission.
enum BalanceReminder {

    /// Read by the notification delegate, which runs off the main actor.
    nonisolated static let identifier = "monthly-balance-reminder"

    // Notifications are scheduled per device, so the settings live in this device's defaults.
    static let enabledKey = "reminder.enabled"
    static let dayKey = "reminder.day"
    static let minuteKey = "reminder.minute"

    /// The 1st of the month.
    static let defaultDay = 1
    /// 9:00 AM, in minutes after midnight.
    static let defaultMinute = 9 * 60

    /// Days 29–31 don't exist in every month, so the reminder day goes up to 28.
    static let days = 1...28

    /// When the reminder repeats: `day` of every month at `minute` minutes after midnight.
    static func dateComponents(day: Int, minute: Int) -> DateComponents {
        DateComponents(day: min(max(day, days.lowerBound), days.upperBound), hour: minute / 60, minute: minute % 60)
    }

    /// The notification itself. It never includes amounts, since it can show on a locked phone.
    static func content() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to update your balances"
        content.body = "Take a minute to check your accounts and see how your net worth moved this month."
        content.sound = .default
        return content
    }

    /// Asks for permission if needed. Returns whether notifications are allowed.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Schedules the monthly reminder, replacing any earlier one.
    static func schedule(day: Int, minute: Int) async {
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(day: day, minute: minute),
            repeats: true
        )
        let request = UNNotificationRequest(identifier: identifier, content: content(), trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Whether notifications were turned off for the app in iOS Settings.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Opening the App from the Reminder

/// Carries "the reminder was tapped" from the notification delegate to the screens. It
/// outlives the screens, so a tap that arrives behind the Face ID lock is still handled after
/// unlocking, and only once.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Counts reminder taps, so the tab bar can switch to Home on each one.
    private(set) var checkInRequests = 0
    /// Set by a reminder tap until Home opens the check-in.
    var hasPendingCheckIn = false

    func requestCheckIn() {
        checkInRequests += 1
        hasPendingCheckIn = true
    }
}

/// Receives notification taps. Set as the notification center's delegate at launch, so a
/// tap that launches the app is delivered too.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == BalanceReminder.identifier else { return }
        await MainActor.run {
            AppRouter.shared.requestCheckIn()
        }
    }

    /// Shows the reminder as a banner even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
