import Foundation

/// A fixed UTC calendar so tests don't depend on the machine's time zone.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    /// Day 0 of every test plan.
    static let planStart = date(2026, 11, 24)

    /// `days` after the plan start, at the given time.
    static func day(_ days: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: days, to: planStart)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }
}
