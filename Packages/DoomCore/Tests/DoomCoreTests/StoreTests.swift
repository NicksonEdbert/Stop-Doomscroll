import XCTest
@testable import DoomCore

final class StoreTests: XCTestCase {
    func testRoundTripsAppData() throws {
        let cal = TestClock.calendar
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileStore(url: dir.appendingPathComponent("nested/data.json"))

        XCTAssertNil(try store.load())

        var data = AppData.fresh(now: TestClock.day(0, 15), calendar: cal)
        data.plan.requestChange(to: .fixed(minutes: 45), now: TestClock.day(1), calendar: cal)
        data.ledger.foregroundBegan(.instagram, at: TestClock.day(1, 10))
        data.ledger.foregroundEnded(.instagram, at: TestClock.day(1, 10, 7))
        data.ledger.foregroundBegan(.youtube, at: TestClock.day(1, 11))
        data.ledger.grantWindow(for: .tiktok, minutes: 5, at: TestClock.day(1, 12), emergency: true)
        data.ledger.record(OpenAttempt(app: .tiktok, date: TestClock.day(1, 12), outcome: .emergency, intention: .bored))
        data.onboardingDone = true

        try store.save(data)
        XCTAssertEqual(try store.load(), data)
    }
}
