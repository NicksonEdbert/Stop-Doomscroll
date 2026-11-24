import XCTest
@testable import DoomCore

final class LedgerTests: XCTestCase {
    private let cal = TestClock.calendar

    func testCountsTimeBetweenOpenAndClose() {
        var ledger = Ledger()
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 10, 0))
        let interval = ledger.foregroundEnded(.instagram, at: TestClock.day(0, 10, 12))

        XCTAssertEqual(interval?.duration, 12 * 60)
        XCTAssertFalse(ledger.isOnScreen(.instagram))
        XCTAssertEqual(ledger.usedSeconds(onDayOf: TestClock.day(0), now: TestClock.day(0, 23), calendar: cal), 12 * 60)
    }

    func testCountsAStretchStillInProgress() {
        var ledger = Ledger()
        ledger.foregroundBegan(.tiktok, at: TestClock.day(0, 10, 0))

        XCTAssertTrue(ledger.isOnScreen(.tiktok))
        XCTAssertEqual(ledger.usedSeconds(onDayOf: TestClock.day(0), now: TestClock.day(0, 10, 5), calendar: cal), 5 * 60)
    }

    func testSplitsUsageAtMidnight() {
        var ledger = Ledger()
        ledger.foregroundBegan(.youtube, at: TestClock.day(0, 23, 50))
        ledger.foregroundEnded(.youtube, at: TestClock.day(1, 0, 10))
        let later = TestClock.day(1, 12)

        XCTAssertEqual(ledger.usedSeconds(onDayOf: TestClock.day(0), now: later, calendar: cal), 10 * 60)
        XCTAssertEqual(ledger.usedSeconds(onDayOf: TestClock.day(1), now: later, calendar: cal), 10 * 60)
    }

    func testCapsAStretchWhoseCloseWasMissed() {
        var ledger = Ledger()
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 10))
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 15))

        XCTAssertEqual(ledger.intervals.count, 1)
        XCTAssertEqual(ledger.intervals.first?.duration, Ledger.maxIntervalSeconds)
        XCTAssertEqual(ledger.openSince[TargetApp.instagram.rawValue], TestClock.day(0, 15))
    }

    func testCapsAnOpenStretchWhenCountingUsage() {
        var ledger = Ledger()
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 8))

        XCTAssertEqual(
            ledger.usedSeconds(onDayOf: TestClock.day(0), now: TestClock.day(0, 20), calendar: cal),
            Ledger.maxIntervalSeconds
        )
    }

    func testCloseWithoutOpenIsIgnored() {
        var ledger = Ledger()
        XCTAssertNil(ledger.foregroundEnded(.instagram, at: TestClock.day(0)))
        XCTAssertTrue(ledger.intervals.isEmpty)
    }

    func testFiltersUsageByApp() {
        var ledger = Ledger()
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 10, 0))
        ledger.foregroundEnded(.instagram, at: TestClock.day(0, 10, 10))
        ledger.foregroundBegan(.tiktok, at: TestClock.day(0, 11, 0))
        ledger.foregroundEnded(.tiktok, at: TestClock.day(0, 11, 4))
        let now = TestClock.day(0, 20)

        XCTAssertEqual(ledger.usedSeconds(onDayOf: now, now: now, calendar: cal, app: .instagram), 10 * 60)
        XCTAssertEqual(ledger.usedSeconds(onDayOf: now, now: now, calendar: cal, app: .tiktok), 4 * 60)
        XCTAssertEqual(ledger.usedSeconds(onDayOf: now, now: now, calendar: cal, app: .youtube), 0)
        XCTAssertEqual(ledger.usedSeconds(onDayOf: now, now: now, calendar: cal), 14 * 60)
    }

    func testActiveWindowIsPerAppAndEnds() {
        var ledger = Ledger()
        ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 10, 0))

        XCTAssertNotNil(ledger.activeWindow(for: .instagram, at: TestClock.day(0, 10, 9)))
        XCTAssertNil(ledger.activeWindow(for: .instagram, at: TestClock.day(0, 10, 10)))
        XCTAssertNil(ledger.activeWindow(for: .tiktok, at: TestClock.day(0, 10, 5)))
    }

    func testCountsEmergencyUnlocksPerDay() {
        var ledger = Ledger()
        ledger.grantWindow(for: .instagram, minutes: 5, at: TestClock.day(0, 21), emergency: true)
        ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 22))

        XCTAssertEqual(ledger.emergencyCount(onDayOf: TestClock.day(0), calendar: cal), 1)
        XCTAssertEqual(ledger.emergencyCount(onDayOf: TestClock.day(1), calendar: cal), 0)
    }

    func testPruneDropsOldHistory() {
        var ledger = Ledger()
        ledger.foregroundBegan(.instagram, at: TestClock.day(0, 10))
        ledger.foregroundEnded(.instagram, at: TestClock.day(0, 11))
        ledger.record(OpenAttempt(app: .instagram, date: TestClock.day(0, 10), outcome: .allowed))
        ledger.grantWindow(for: .instagram, minutes: 10, at: TestClock.day(0, 10))
        ledger.record(OpenAttempt(app: .tiktok, date: TestClock.day(5), outcome: .resisted))

        ledger.prune(before: TestClock.day(3))

        XCTAssertTrue(ledger.intervals.isEmpty)
        XCTAssertTrue(ledger.windows.isEmpty)
        XCTAssertEqual(ledger.attempts.count, 1)
    }
}
