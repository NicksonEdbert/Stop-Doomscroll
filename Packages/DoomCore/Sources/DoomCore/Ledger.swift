import Foundation

/// The reason you gave on the pause screen.
public enum Intention: String, Codable, CaseIterable, Sendable {
    case message
    case post
    case lookup
    case bored

    public var label: String {
        switch self {
        case .message: return "Reply to a message"
        case .post: return "Post something"
        case .lookup: return "Look something up"
        case .bored: return "Just bored"
        }
    }
}

/// How a pause or block screen ended.
public enum AttemptOutcome: String, Codable, Sendable {
    /// You finished the pause and chose a session.
    case allowed
    /// You closed the pause without opening the app.
    case resisted
    /// The budget was used up, so the app stayed blocked.
    case blocked
    /// You used the once-a-day emergency unlock.
    case emergency
}

public struct OpenAttempt: Codable, Equatable, Sendable {
    public var app: TargetApp
    public var date: Date
    public var outcome: AttemptOutcome
    public var intention: Intention?

    public init(app: TargetApp, date: Date, outcome: AttemptOutcome, intention: Intention? = nil) {
        self.app = app
        self.date = date
        self.outcome = outcome
        self.intention = intention
    }
}

/// A stretch of time an app may be opened without another pause.
public struct AccessWindow: Codable, Equatable, Sendable {
    public var app: TargetApp
    public var start: Date
    public var end: Date
    public var isEmergency: Bool

    public func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

/// Time an app actually spent on screen, from its "opened" to its "closed" automation.
public struct ForegroundInterval: Codable, Equatable, Sendable {
    public var app: TargetApp
    public var start: Date
    public var end: Date

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Everything that has happened: time on screen, granted sessions and pause outcomes.
public struct Ledger: Codable, Equatable, Sendable {
    /// Longest single stretch counted if a "closed" event never arrives.
    public static let maxIntervalSeconds: TimeInterval = 2 * 60 * 60
    public static let emergencyMinutes = 5
    public static let emergencyPerDay = 1

    public var intervals: [ForegroundInterval] = []
    /// Apps currently on screen, keyed by `TargetApp.rawValue`, with the time they opened.
    public var openSince: [String: Date] = [:]
    public var windows: [AccessWindow] = []
    public var attempts: [OpenAttempt] = []

    public init() {}

    // MARK: Sessions

    public func activeWindow(for app: TargetApp, at date: Date) -> AccessWindow? {
        windows.last { $0.app == app && $0.contains(date) }
    }

    @discardableResult
    public mutating func grantWindow(
        for app: TargetApp,
        minutes: Int,
        at date: Date,
        emergency: Bool = false
    ) -> AccessWindow {
        let window = AccessWindow(
            app: app,
            start: date,
            end: date.addingTimeInterval(TimeInterval(minutes * 60)),
            isEmergency: emergency
        )
        windows.append(window)
        return window
    }

    public func emergencyCount(onDayOf date: Date, calendar: Calendar) -> Int {
        windows.filter { $0.isEmergency && calendar.isDate($0.start, inSameDayAs: date) }.count
    }

    // MARK: Screen time

    public func isOnScreen(_ app: TargetApp) -> Bool {
        openSince[app.rawValue] != nil
    }

    /// The app came on screen inside an allowed session.
    public mutating func foregroundBegan(_ app: TargetApp, at date: Date) {
        if let previous = openSince[app.rawValue] {
            // The matching "closed" event was missed. Count the stale stretch, capped.
            close(app, start: previous, end: date)
        }
        openSince[app.rawValue] = date
    }

    /// The app left the screen. Does nothing if it wasn't being timed.
    @discardableResult
    public mutating func foregroundEnded(_ app: TargetApp, at date: Date) -> ForegroundInterval? {
        guard let start = openSince.removeValue(forKey: app.rawValue) else { return nil }
        return close(app, start: start, end: date)
    }

    @discardableResult
    private mutating func close(_ app: TargetApp, start: Date, end: Date) -> ForegroundInterval? {
        let cappedEnd = min(end, start.addingTimeInterval(Self.maxIntervalSeconds))
        guard cappedEnd > start else { return nil }
        let interval = ForegroundInterval(app: app, start: start, end: cappedEnd)
        intervals.append(interval)
        return interval
    }

    /// Seconds on screen during the calendar day containing `date`, including any stretch
    /// still in progress (measured up to `now`). Pass `app` to count only that app.
    public func usedSeconds(
        onDayOf date: Date,
        now: Date,
        calendar: Calendar,
        app: TargetApp? = nil
    ) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        var total: TimeInterval = 0
        for interval in intervals where app == nil || interval.app == app {
            total += Self.overlap(interval.start, interval.end, dayStart, dayEnd)
        }
        for (key, start) in openSince {
            guard let openApp = TargetApp(rawValue: key), app == nil || openApp == app else { continue }
            let end = min(now, start.addingTimeInterval(Self.maxIntervalSeconds))
            total += Self.overlap(start, end, dayStart, dayEnd)
        }
        return total
    }

    private static func overlap(_ start: Date, _ end: Date, _ rangeStart: Date, _ rangeEnd: Date) -> TimeInterval {
        let lower = max(start, rangeStart)
        let upper = min(end, rangeEnd)
        return max(0, upper.timeIntervalSince(lower))
    }

    // MARK: Pause outcomes

    public mutating func record(_ attempt: OpenAttempt) {
        attempts.append(attempt)
    }

    public func attempts(onDayOf date: Date, calendar: Calendar) -> [OpenAttempt] {
        attempts.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: Housekeeping

    /// Drops history that ended before `cutoff`, to keep the data file small.
    public mutating func prune(before cutoff: Date) {
        intervals.removeAll { $0.end < cutoff }
        windows.removeAll { $0.end < cutoff }
        attempts.removeAll { $0.date < cutoff }
    }
}
