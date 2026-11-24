import XCTest
@testable import DoomCore

final class StatsTests: XCTestCase {
    private let cal = TestClock.calendar
    private lazy var plan = BudgetPlan(planStart: TestClock.planStart, calendar: cal)

    private func use(_ app: TargetApp, minutes: Int, day: Int, in ledger: inout Ledger) {
        let start = TestClock.day(day, 10)
        ledger.foregroundBegan(app, at: start)
        ledger.foregroundEnded(app, at: start.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func testSummaryCountsTimeAndOutcomes() {
        var ledger = Ledger()
        use(.instagram, minutes: 20, day: 0, in: &ledger)
        use(.youtube, minutes: 5, day: 0, in: &ledger)
        ledger.record(OpenAttempt(app: .instagram, date: TestClock.day(0, 9), outcome: .allowed, intention: .message))
        ledger.record(OpenAttempt(app: .tiktok, date: TestClock.day(0, 13), outcome: .resisted, intention: .bored))
        ledger.record(OpenAttempt(app: .tiktok, date: TestClock.day(1, 13), outcome: .resisted))

        let summary = Stats.summary(forDayOf: TestClock.day(0), ledger: ledger, plan: plan, now: TestClock.day(0, 20), calendar: cal)

        XCTAssertEqual(summary.day, TestClock.planStart)
        XCTAssertEqual(summary.usedMinutes, 25)
        XCTAssertEqual(summary.perApp[.instagram], 20 * 60)
        XCTAssertEqual(summary.perApp[.tiktok], 0)
        XCTAssertEqual(summary.budgetMinutes, 90)
        XCTAssertEqual(summary.opens, 2)
        XCTAssertEqual(summary.resisted, 1)
        XCTAssertTrue(summary.isUnderBudget)
    }

    func testStreakStopsAtTheFirstDayOverBudget() {
        var ledger = Ledger()
        use(.instagram, minutes: 30, day: 0, in: &ledger)
        use(.instagram, minutes: 100, day: 1, in: &ledger) // over 90
        use(.tiktok, minutes: 10, day: 2, in: &ledger)

        // Day 3 is empty; today (day 4) isn't counted yet.
        XCTAssertEqual(Stats.streak(ledger: ledger, plan: plan, now: TestClock.day(4), calendar: cal), 2)
    }

    func testStreakDoesNotCountDaysBeforeThePlan() {
        XCTAssertEqual(Stats.streak(ledger: Ledger(), plan: plan, now: TestClock.day(3), calendar: cal), 3)
        XCTAssertEqual(Stats.streak(ledger: Ledger(), plan: plan, now: TestClock.day(0), calendar: cal), 0)
    }

    func testHistoryEndsWithToday() {
        let history = Stats.history(days: 7, ledger: Ledger(), plan: plan, now: TestClock.day(10, 18), calendar: cal)

        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.last?.day, TestClock.day(10, 0))
        XCTAssertEqual(history.first?.day, TestClock.day(4, 0))
        XCTAssertEqual(history.first?.budgetMinutes, 90)
        XCTAssertEqual(history.last?.budgetMinutes, 75)
    }
}
