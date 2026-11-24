import Foundation
import SwiftUI
import UIKit
import DoomCore

/// Which full-screen gate to show.
enum Route: Identifiable, Equatable {
    case pause(TargetApp)
    case blocked(TargetApp)

    var id: String {
        switch self {
        case .pause(let app): return "pause-\(app.rawValue)"
        case .blocked(let app): return "blocked-\(app.rawValue)"
        }
    }
}

/// The app's single source of truth. Shared by the views and the Shortcuts actions, which
/// run in the same process.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    /// How long history is kept.
    private static let historyDays = 180

    @Published private(set) var data: AppData
    @Published var route: Route?
    @Published var openFailedFor: TargetApp?

    let calendar = Calendar.current
    private let store: FileStore

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let store = FileStore(url: directory.appendingPathComponent("StopDoomscroll/data.json"))
        self.store = store

        do {
            data = try store.load() ?? AppData.fresh(now: Date(), calendar: Calendar.current)
        } catch {
            // Keep the unreadable file for inspection rather than overwriting it.
            let backup = store.url.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: store.url, to: backup)
            data = AppData.fresh(now: Date(), calendar: Calendar.current)
        }
    }

    // MARK: - Reading state

    func decision(for app: TargetApp, at date: Date = Date()) -> GateDecision {
        Gatekeeper.decide(for: app, ledger: data.ledger, plan: data.plan, now: date, calendar: calendar)
    }

    func remainingSeconds(at date: Date = Date()) -> TimeInterval {
        Gatekeeper.remainingSeconds(ledger: data.ledger, plan: data.plan, now: date, calendar: calendar)
    }

    func summary(at date: Date = Date()) -> DaySummary {
        Stats.summary(forDayOf: date, ledger: data.ledger, plan: data.plan, now: date, calendar: calendar)
    }

    func history(days: Int = 7, at date: Date = Date()) -> [DaySummary] {
        Stats.history(days: days, ledger: data.ledger, plan: data.plan, now: date, calendar: calendar)
    }

    func streak(at date: Date = Date()) -> Int {
        Stats.streak(ledger: data.ledger, plan: data.plan, now: date, calendar: calendar)
    }

    func budgetMinutes(at date: Date = Date()) -> Int {
        data.plan.minutes(on: date, calendar: calendar)
    }

    func currentMode(at date: Date = Date()) -> BudgetMode {
        data.plan.mode(on: date, calendar: calendar)
    }

    /// What to set the built-in Screen Time App Limit to: the budget plus a little slack, so
    /// it only kicks in if this app's automations are skipped.
    func screenTimeLimitMinutes(at date: Date = Date()) -> Int {
        budgetMinutes(at: date) + 10
    }

    /// "6th open today · 22 of 60 min left"
    func pauseSubtitle(for app: TargetApp, at date: Date = Date()) -> String {
        let opens = data.ledger.attempts(onDayOf: date, calendar: calendar).count + 1
        let left = Int(remainingSeconds(at: date) / 60)
        return "\(DisplayFormat.ordinal(opens)) open today · \(left) of \(budgetMinutes(at: date)) min left"
    }

    func planDescription(at date: Date = Date()) -> String {
        let plan = data.plan
        switch plan.mode(on: date, calendar: calendar) {
        case .fixed(let minutes):
            return "Fixed: \(minutes) min a day"
        case .stepDown:
            let week = plan.weekIndex(on: date, calendar: calendar) + 1
            let today = plan.scheduledMinutes(on: date, calendar: calendar)
            guard let next = plan.nextStepDate(after: date, calendar: calendar) else {
                return "Week \(week): \(today) min a day (final step)"
            }
            let nextMinutes = plan.scheduledMinutes(on: next, calendar: calendar)
            return "Week \(week): \(today) min a day. Drops to \(nextMinutes) min on \(DisplayFormat.day(next))."
        }
    }

    func pendingChangeDescription(at date: Date = Date()) -> String? {
        guard let pending = data.plan.pendingChange(after: date, calendar: calendar) else { return nil }
        let minutes = data.plan.minutes(for: pending.mode, on: pending.effectiveDay, calendar: calendar)
        return "From \(DisplayFormat.day(pending.effectiveDay)): \(minutes) min a day."
    }

    var timeUntilMidnightText: String {
        let now = Date()
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return DisplayFormat.duration(midnight.timeIntervalSince(now))
    }

    // MARK: - Shortcuts actions

    /// Called by the "When <app> is opened" automation. Returns true inside a granted session,
    /// and starts timing the app.
    func checkAccess(_ app: TargetApp) -> Bool {
        let now = Date()
        guard case .allowed = decision(for: app, at: now) else { return false }
        data.ledger.foregroundBegan(app, at: now)
        save()

        let remaining = remainingSeconds(at: now)
        if remaining > 0 {
            Notifications.scheduleBudgetUsedUp(in: remaining, app: app, budgetMinutes: budgetMinutes(at: now))
        }
        return true
    }

    /// Called by the automation when there's no session: shows the pause or block screen.
    func presentGate(for app: TargetApp) {
        switch decision(for: app) {
        case .allowed:
            route = nil
            openTargetApp(app)
        case .needsPause:
            route = .pause(app)
        case .blocked:
            data.ledger.record(OpenAttempt(app: app, date: Date(), outcome: .blocked))
            save()
            route = .blocked(app)
        }
    }

    /// Called by the "When <app> is closed" automation.
    func appClosed(_ app: TargetApp) {
        data.ledger.foregroundEnded(app, at: Date())
        save()
        Notifications.cancelBudgetUsedUp()
    }

    // MARK: - Pause and block outcomes

    func grantSession(for app: TargetApp, minutes: Int, intention: Intention?) {
        let now = Date()
        guard case .needsPause = decision(for: app, at: now) else { return }
        let window = data.ledger.grantWindow(for: app, minutes: minutes, at: now)
        data.ledger.record(OpenAttempt(app: app, date: now, outcome: .allowed, intention: intention))
        save()
        Notifications.scheduleSessionOver(for: app, at: window.end)
        route = nil
        openTargetApp(app)
    }

    func resist(_ app: TargetApp, intention: Intention?) {
        data.ledger.record(OpenAttempt(app: app, date: Date(), outcome: .resisted, intention: intention))
        save()
        route = nil
    }

    func useEmergency(for app: TargetApp) {
        let now = Date()
        guard case .blocked(emergencyAvailable: true) = decision(for: app, at: now) else { return }
        let window = data.ledger.grantWindow(for: app, minutes: Ledger.emergencyMinutes, at: now, emergency: true)
        data.ledger.record(OpenAttempt(app: app, date: now, outcome: .emergency))
        save()
        Notifications.scheduleSessionOver(for: app, at: window.end)
        route = nil
        openTargetApp(app)
    }

    func dismissRoute() {
        route = nil
    }

    // MARK: - Settings

    @discardableResult
    func requestBudget(_ mode: BudgetMode) -> BudgetChange {
        let change = data.plan.requestChange(to: mode, now: Date(), calendar: calendar)
        save()
        refreshReminders()
        return change
    }

    func completeOnboarding() {
        data.onboardingDone = true
        save()
    }

    #if DEBUG
    /// Testing only: start over as if freshly installed.
    func eraseAllData() {
        data = AppData.fresh(now: Date(), calendar: calendar)
        save()
        refreshReminders()
    }
    #endif

    // MARK: - Lifecycle

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Leaving mid-pause abandons it; the next open starts a fresh one.
            route = nil
        case .active:
            data.ledger.prune(before: Date().addingTimeInterval(-Double(Self.historyDays) * 86_400))
            save()
            refreshReminders()
        default:
            break
        }
    }

    func refreshReminders() {
        Notifications.refreshReminders(plan: data.plan, now: Date(), calendar: calendar)
    }

    // MARK: - Private

    private func save() {
        do {
            try store.save(data)
        } catch {
            print("Stop Doomscroll: couldn't save data: \(error)")
        }
    }

    private func openTargetApp(_ app: TargetApp) {
        openFirstAvailable(app.urlSchemes.compactMap { URL(string: $0) }, app: app)
    }

    private func openFirstAvailable(_ urls: [URL], app: TargetApp) {
        guard let url = urls.first else {
            openFailedFor = app
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            Task { @MainActor in
                AppModel.shared.openFirstAvailable(Array(urls.dropFirst()), app: app)
            }
        }
    }
}
