import Foundation
import UserNotifications
import DoomCore

/// Local notifications. There's no server; everything is scheduled on the phone.
enum Notifications {
    private static let budgetUsedUpID = "budget-used-up"
    private static let planStepID = "plan-step"
    private static let expiryID = "app-expiry"

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// The session picked on the pause screen has ended.
    static func scheduleSessionOver(for app: TargetApp, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(app.displayName) session over"
        content.body = "Time to close it. Opening it again means another pause."
        content.sound = .default
        schedule(id: "session-over-\(app.rawValue)", content: content, at: date)
    }

    /// Fires if you stay in the app until today's budget runs out.
    static func scheduleBudgetUsedUp(in seconds: TimeInterval, app: TargetApp, budgetMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Today's \(budgetMinutes) min are used up"
        content.body = "Close \(app.displayName) now. It stays locked until midnight."
        content.sound = .default
        schedule(id: budgetUsedUpID, content: content, at: Date().addingTimeInterval(seconds))
    }

    static func cancelBudgetUsedUp() {
        center.removePendingNotificationRequests(withIdentifiers: [budgetUsedUpID])
    }

    /// Re-schedules the weekly step-down reminder and the "re-install before it expires"
    /// reminder. Safe to call often.
    static func refreshReminders(plan: BudgetPlan, now: Date, calendar: Calendar) {
        center.removePendingNotificationRequests(withIdentifiers: [planStepID, expiryID])

        if let stepDay = plan.nextStepDate(after: now, calendar: calendar),
           plan.mode(on: stepDay, calendar: calendar) == .stepDown,
           let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: stepDay) {
            let week = plan.weekIndex(on: stepDay, calendar: calendar) + 1
            let minutes = plan.scheduledMinutes(on: stepDay, calendar: calendar)
            let content = UNMutableNotificationContent()
            content.title = "Week \(week): your budget is now \(minutes) min"
            content.body = "Ask your Screen Time passcode holder to lower your App Limit to \(minutes + 10) min."
            schedule(id: planStepID, content: content, at: morning)
        }

        if let expiry = ProvisioningInfo.expirationDate {
            let reminder = expiry.addingTimeInterval(-24 * 60 * 60)
            let content = UNMutableNotificationContent()
            content.title = "Stop Doomscroll stops working tomorrow"
            content.body = "Connect your iPhone to your Mac and press Run in Xcode to renew it for another 7 days."
            content.sound = .default
            schedule(id: expiryID, content: content, at: reminder)
        }
    }

    private static func schedule(id: String, content: UNNotificationContent, at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error {
                print("Stop Doomscroll: couldn't schedule \(id): \(error)")
            }
        }
    }
}
