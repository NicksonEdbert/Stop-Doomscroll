import Foundation

/// What should happen when a target app is opened.
public enum GateDecision: Equatable, Sendable {
    /// Inside a granted session: let it open.
    case allowed(until: Date)
    /// Budget left, but no session: show the pause screen.
    case needsPause(remainingSeconds: TimeInterval)
    /// Budget used up: show the block screen.
    case blocked(emergencyAvailable: Bool)
}

public enum Gatekeeper {
    /// Session lengths offered on the pause screen, in minutes.
    public static let sessionChoices = [5, 10, 15]

    /// Budget left today across all target apps.
    public static func remainingSeconds(
        ledger: Ledger,
        plan: BudgetPlan,
        now: Date,
        calendar: Calendar
    ) -> TimeInterval {
        let budget = TimeInterval(plan.minutes(on: now, calendar: calendar) * 60)
        let used = ledger.usedSeconds(onDayOf: now, now: now, calendar: calendar)
        return max(0, budget - used)
    }

    public static func decide(
        for app: TargetApp,
        ledger: Ledger,
        plan: BudgetPlan,
        now: Date,
        calendar: Calendar
    ) -> GateDecision {
        let remaining = remainingSeconds(ledger: ledger, plan: plan, now: now, calendar: calendar)

        // A normal session ends early once the budget runs out; an emergency one doesn't.
        if let window = ledger.activeWindow(for: app, at: now), window.isEmergency || remaining > 0 {
            return .allowed(until: window.end)
        }
        if remaining > 0 {
            return .needsPause(remainingSeconds: remaining)
        }
        let emergencyUsed = ledger.emergencyCount(onDayOf: now, calendar: calendar)
        return .blocked(emergencyAvailable: emergencyUsed < Ledger.emergencyPerDay)
    }

    /// Session lengths to offer, capped by what's left of the budget.
    /// For example, 12 minutes left offers 5, 10 and 12.
    public static func sessionOptions(remainingSeconds: TimeInterval) -> [Int] {
        guard remainingSeconds > 0 else { return [] }
        let remainingMinutes = Int((remainingSeconds / 60).rounded(.up))
        var options = sessionChoices.filter { $0 <= remainingMinutes }
        if let longest = sessionChoices.last, remainingMinutes < longest, !options.contains(remainingMinutes) {
            options.append(remainingMinutes)
        }
        return options
    }
}
