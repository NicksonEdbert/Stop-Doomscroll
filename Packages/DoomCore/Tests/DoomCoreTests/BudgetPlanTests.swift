import XCTest
@testable import DoomCore

final class BudgetPlanTests: XCTestCase {
    private let cal = TestClock.calendar

    private func makePlan() -> BudgetPlan {
        BudgetPlan(planStart: TestClock.day(0, 15), calendar: cal)
    }

    func testPlanStartIsStartOfDay() {
        XCTAssertEqual(makePlan().planStart, TestClock.planStart)
    }

    func testStepsDownWeeklyToTheFloor() {
        let plan = makePlan()
        let expected: [(day: Int, minutes: Int)] = [
            (0, 90), (6, 90), (7, 75), (13, 75), (14, 60), (21, 45), (28, 30), (35, 15), (42, 15), (365, 15),
        ]
        for (day, minutes) in expected {
            XCTAssertEqual(plan.minutes(on: TestClock.day(day), calendar: cal), minutes, "day \(day)")
        }
    }

    func testDatesBeforeThePlanUseWeekOne() {
        XCTAssertEqual(makePlan().minutes(on: TestClock.day(-3), calendar: cal), 90)
    }

    func testLoweringAppliesToday() {
        var plan = makePlan()
        let now = TestClock.day(2, 15)
        let change = plan.requestChange(to: .fixed(minutes: 30), now: now, calendar: cal)

        XCTAssertEqual(change.effectiveDay, cal.startOfDay(for: now))
        XCTAssertEqual(plan.minutes(on: now, calendar: cal), 30)
        XCTAssertNil(plan.pendingChange(after: now, calendar: cal))
    }

    func testRaisingOnlyAppliesTomorrow() {
        var plan = makePlan()
        let now = TestClock.day(2, 15)
        plan.requestChange(to: .fixed(minutes: 30), now: now, calendar: cal)
        let change = plan.requestChange(to: .fixed(minutes: 60), now: now, calendar: cal)

        XCTAssertEqual(change.effectiveDay, TestClock.day(3, 0))
        XCTAssertEqual(plan.minutes(on: now, calendar: cal), 30)
        XCTAssertEqual(plan.minutes(on: TestClock.day(3), calendar: cal), 60)
        XCTAssertEqual(plan.pendingChange(after: now, calendar: cal), change)
    }

    func testLoweringCancelsAPendingRaise() {
        var plan = makePlan()
        let now = TestClock.day(2, 15)
        plan.requestChange(to: .fixed(minutes: 30), now: now, calendar: cal)
        plan.requestChange(to: .fixed(minutes: 120), now: now, calendar: cal)
        plan.requestChange(to: .fixed(minutes: 20), now: now, calendar: cal)

        XCTAssertEqual(plan.minutes(on: now, calendar: cal), 20)
        XCTAssertEqual(plan.minutes(on: TestClock.day(3), calendar: cal), 20)
        XCTAssertNil(plan.pendingChange(after: now, calendar: cal))
        XCTAssertEqual(plan.changes.count, 1)
    }

    func testReturningToStepDownWhenItIsHigherWaitsForTomorrow() {
        var plan = makePlan()
        let now = TestClock.day(10, 9) // week 2 → 75 min
        plan.requestChange(to: .fixed(minutes: 30), now: now, calendar: cal)
        plan.requestChange(to: .stepDown, now: now, calendar: cal)

        XCTAssertEqual(plan.minutes(on: now, calendar: cal), 30)
        XCTAssertEqual(plan.minutes(on: TestClock.day(11), calendar: cal), 75)
        XCTAssertEqual(plan.mode(on: TestClock.day(11), calendar: cal), .stepDown)
    }

    func testKeepingTheSameBudgetAppliesToday() {
        var plan = makePlan()
        let now = TestClock.day(1)
        let change = plan.requestChange(to: .fixed(minutes: 90), now: now, calendar: cal)
        XCTAssertEqual(change.effectiveDay, cal.startOfDay(for: now))
    }

    func testFixedMinutesAreClamped() {
        let plan = makePlan()
        let now = TestClock.day(0)
        XCTAssertEqual(plan.minutes(for: .fixed(minutes: 0), on: now, calendar: cal), BudgetPlan.minimumMinutes)
        XCTAssertEqual(plan.minutes(for: .fixed(minutes: 9999), on: now, calendar: cal), BudgetPlan.maximumMinutes)
    }

    func testNextStepDate() {
        let plan = makePlan()
        XCTAssertEqual(plan.nextStepDate(after: TestClock.day(3), calendar: cal), TestClock.day(7, 0))
        XCTAssertEqual(plan.nextStepDate(after: TestClock.day(29), calendar: cal), TestClock.day(35, 0))
        XCTAssertNil(plan.nextStepDate(after: TestClock.day(35), calendar: cal))
        XCTAssertNil(plan.nextStepDate(after: TestClock.day(100), calendar: cal))
    }
}
