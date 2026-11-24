import XCTest
@testable import DoomCore

final class GatekeeperTests: XCTestCase {
    private let cal = TestClock.calendar
    private lazy var plan = BudgetPlan(planStart: TestClock.planStart, calendar: cal)

    private func decide(_ app: TargetApp, _ ledger: Ledger, at now: Date) -> GateDecision {
        Gatekeeper.decide(for: app, ledger: ledger, plan: plan, now: now, calendar: cal)
    }

    /// Uses `minutes` of Instagram ending at 09:00 on `day`.
    private func ledgerWithUsage(minutes: Int, day: Int = 0) -> Ledger {
        var ledger = Ledger()
        let end = TestClock.day(day, 9)
        ledger.foregroundBegan(.instagram, at: end.addingTimeInterval(TimeInterval(-minutes * 60)))
        ledger.foregroundEnded(.instagram, at: end)
        return ledger
    }

    func testFreshDayNeedsAPause() {
        XCTAssertEqual(decide(.instagram, Ledger(), at: TestClock.day(0)), .needsPause(remainingSeconds: 90 * 60))
    }

    func testAllowedInsideASession() {
        var ledger = Ledger()
        let window = ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 12, 0))

        XCTAssertEqual(decide(.instagram, ledger, at: TestClock.day(0, 12, 5)), .allowed(until: window.end))
        XCTAssertEqual(decide(.tiktok, ledger, at: TestClock.day(0, 12, 5)), .needsPause(remainingSeconds: 90 * 60))
    }

    func testNeedsAPauseAgainAfterTheSessionEnds() {
        var ledger = Ledger()
        ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 12, 0))

        guard case .needsPause = decide(.instagram, ledger, at: TestClock.day(0, 12, 10)) else {
            return XCTFail("expected a pause once the session is over")
        }
    }

    func testBlockedOnceTheBudgetIsUsedEvenInsideASession() {
        var ledger = ledgerWithUsage(minutes: 90)
        ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 9))

        XCTAssertEqual(decide(.instagram, ledger, at: TestClock.day(0, 9, 1)), .blocked(emergencyAvailable: true))
    }

    func testBudgetResetsAtMidnight() {
        let ledger = ledgerWithUsage(minutes: 90)
        XCTAssertEqual(decide(.instagram, ledger, at: TestClock.day(1, 0, 1)), .needsPause(remainingSeconds: 90 * 60))
    }

    func testRemainingAccountsForOvertimeAcrossApps() {
        var ledger = ledgerWithUsage(minutes: 50)
        ledger.foregroundBegan(.youtube, at: TestClock.day(0, 10, 0))
        ledger.foregroundEnded(.youtube, at: TestClock.day(0, 10, 25))

        XCTAssertEqual(decide(.tiktok, ledger, at: TestClock.day(0, 11)), .needsPause(remainingSeconds: 15 * 60))
    }

    func testEmergencySessionIsAllowedOverBudget() {
        var ledger = ledgerWithUsage(minutes: 95)
        let window = ledger.grantWindow(for: .instagram, minutes: Ledger.emergencyMinutes, at: TestClock.day(0, 10), emergency: true)

        XCTAssertEqual(decide(.instagram, ledger, at: TestClock.day(0, 10, 2)), .allowed(until: window.end))
        XCTAssertEqual(decide(.instagram, ledger, at: TestClock.day(0, 10, 6)), .blocked(emergencyAvailable: false))
    }

    func testSessionOptions() {
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 60 * 60), [5, 10, 15])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 15 * 60), [5, 10, 15])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 12 * 60), [5, 10, 12])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 10 * 60), [5, 10])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 3 * 60), [3])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 30), [1])
        XCTAssertEqual(Gatekeeper.sessionOptions(remainingSeconds: 0), [])
    }
}
