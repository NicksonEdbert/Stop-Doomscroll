import Foundation

/// How the daily budget is chosen.
public enum BudgetMode: Codable, Equatable, Sendable {
    /// Start high and drop by a fixed step every week until the floor.
    case stepDown
    /// The same number of minutes every day.
    case fixed(minutes: Int)
}

/// A budget decision and the day it starts to apply.
public struct BudgetChange: Codable, Equatable, Sendable {
    public var mode: BudgetMode
    /// Start of the day the change takes effect.
    public var effectiveDay: Date

    public init(mode: BudgetMode, effectiveDay: Date) {
        self.mode = mode
        self.effectiveDay = effectiveDay
    }
}

/// The combined daily budget for all target apps.
///
/// By default it steps down weekly: 90 → 75 → 60 → 45 → 30 → 15 minutes, then stays at 15.
/// Lowering the budget applies straight away. Raising it only applies from tomorrow, so a
/// craving in the moment can't buy more time today.
public struct BudgetPlan: Codable, Equatable, Sendable {
    public static let minimumMinutes = 1
    public static let maximumMinutes = 240

    /// Start of the first day of week 1.
    public var planStart: Date
    public var startMinutes: Int
    public var weeklyStepMinutes: Int
    public var floorMinutes: Int
    /// Budget changes, sorted by `effectiveDay`.
    public private(set) var changes: [BudgetChange]

    public init(
        planStart: Date,
        startMinutes: Int = 90,
        weeklyStepMinutes: Int = 15,
        floorMinutes: Int = 15,
        calendar: Calendar = .current
    ) {
        self.planStart = calendar.startOfDay(for: planStart)
        self.startMinutes = startMinutes
        self.weeklyStepMinutes = weeklyStepMinutes
        self.floorMinutes = floorMinutes
        self.changes = []
    }

    /// Zero-based week of the step-down plan that `date` falls in.
    public func weekIndex(on date: Date, calendar: Calendar) -> Int {
        let day = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: planStart, to: day).day ?? 0
        return max(0, days) / 7
    }

    /// What the step-down schedule says for `date`, ignoring any changes.
    public func scheduledMinutes(on date: Date, calendar: Calendar) -> Int {
        max(floorMinutes, startMinutes - weekIndex(on: date, calendar: calendar) * weeklyStepMinutes)
    }

    /// The mode in force on the day of `date`.
    public func mode(on date: Date, calendar: Calendar) -> BudgetMode {
        let day = calendar.startOfDay(for: date)
        return changes.last(where: { $0.effectiveDay <= day })?.mode ?? .stepDown
    }

    /// The budget, in minutes, for the day of `date`.
    public func minutes(on date: Date, calendar: Calendar) -> Int {
        minutes(for: mode(on: date, calendar: calendar), on: date, calendar: calendar)
    }

    /// The budget `mode` would give on the day of `date`.
    public func minutes(for mode: BudgetMode, on date: Date, calendar: Calendar) -> Int {
        switch mode {
        case .stepDown:
            return scheduledMinutes(on: date, calendar: calendar)
        case .fixed(let minutes):
            return min(max(minutes, Self.minimumMinutes), Self.maximumMinutes)
        }
    }

    /// A change that has been requested but doesn't apply yet, if any.
    public func pendingChange(after date: Date, calendar: Calendar) -> BudgetChange? {
        let day = calendar.startOfDay(for: date)
        return changes.first(where: { $0.effectiveDay > day })
    }

    /// Asks for a new budget mode. Lowering (or keeping) today's budget applies today;
    /// raising it applies from tomorrow. The newest request replaces any pending one.
    @discardableResult
    public mutating func requestChange(to newMode: BudgetMode, now: Date, calendar: Calendar) -> BudgetChange {
        let today = calendar.startOfDay(for: now)
        let current = minutes(on: now, calendar: calendar)
        let proposed = minutes(for: newMode, on: now, calendar: calendar)
        let effectiveDay: Date
        if proposed <= current {
            effectiveDay = today
        } else {
            effectiveDay = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        let change = BudgetChange(mode: newMode, effectiveDay: effectiveDay)
        changes.removeAll { $0.effectiveDay >= effectiveDay }
        changes.append(change)
        return change
    }

    /// When the step-down schedule next lowers the budget, or nil once it has hit the floor.
    public func nextStepDate(after date: Date, calendar: Calendar) -> Date? {
        guard scheduledMinutes(on: date, calendar: calendar) > floorMinutes else { return nil }
        let week = weekIndex(on: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: (week + 1) * 7, to: planStart)
    }
}
