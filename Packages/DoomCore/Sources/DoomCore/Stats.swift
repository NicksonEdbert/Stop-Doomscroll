import Foundation

/// One day's numbers for the Today screen and the weekly chart.
public struct DaySummary: Equatable, Identifiable, Sendable {
    /// Start of the day.
    public var day: Date
    public var usedSeconds: TimeInterval
    public var budgetMinutes: Int
    public var perApp: [TargetApp: TimeInterval]
    /// Pause and block screens resolved that day.
    public var opens: Int
    /// Pauses that ended with you closing the app instead.
    public var resisted: Int

    public var id: Date { day }
    public var usedMinutes: Int { Int((usedSeconds / 60).rounded()) }
    public var isUnderBudget: Bool { usedSeconds <= TimeInterval(budgetMinutes * 60) }
}

public enum Stats {
    public static func summary(
        forDayOf date: Date,
        ledger: Ledger,
        plan: BudgetPlan,
        now: Date,
        calendar: Calendar
    ) -> DaySummary {
        let day = calendar.startOfDay(for: date)
        var perApp: [TargetApp: TimeInterval] = [:]
        for app in TargetApp.allCases {
            perApp[app] = ledger.usedSeconds(onDayOf: day, now: now, calendar: calendar, app: app)
        }
        let attempts = ledger.attempts(onDayOf: day, calendar: calendar)
        return DaySummary(
            day: day,
            usedSeconds: perApp.values.reduce(0, +),
            budgetMinutes: plan.minutes(on: day, calendar: calendar),
            perApp: perApp,
            opens: attempts.count,
            resisted: attempts.filter { $0.outcome == .resisted }.count
        )
    }

    /// The last `days` days, oldest first, ending with today.
    public static func history(
        days: Int,
        ledger: Ledger,
        plan: BudgetPlan,
        now: Date,
        calendar: Calendar
    ) -> [DaySummary] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(0, days)).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                summary(forDayOf: $0, ledger: ledger, plan: plan, now: now, calendar: calendar)
            }
        }
    }

    /// Consecutive finished days under budget, counting back from yesterday and stopping at
    /// the day the plan started.
    public static func streak(
        ledger: Ledger,
        plan: BudgetPlan,
        now: Date,
        calendar: Calendar
    ) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: now)
        while let previous = calendar.date(byAdding: .day, value: -1, to: day), previous >= plan.planStart {
            day = previous
            guard summary(forDayOf: day, ledger: ledger, plan: plan, now: now, calendar: calendar).isUnderBudget else {
                break
            }
            count += 1
        }
        return count
    }
}
