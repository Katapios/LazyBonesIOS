import XCTest
@testable import LazyBones

final class BackgroundTaskServiceTests: XCTestCase {
    var service: BackgroundTaskService!

    override func setUp() {
        super.setUp()
        service = BackgroundTaskService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testCalculateEarliestBeginDate_Before2201() {
        // 21:00 -> expect 22:01 same day
        let cal = Calendar.current
        var comps = cal.dateComponents([.year,.month,.day], from: Date())
        comps.hour = 21; comps.minute = 0; comps.second = 0
        let now = cal.date(from: comps)!
        let expected = cal.date(bySettingHour: 22, minute: 1, second: 0, of: now)!
        XCTAssertEqual(service.calculateEarliestBeginDate(now: now), expected)
    }

    func testCalculateEarliestBeginDate_Between2201And2359() {
        // 22:30 -> expect now (no shift)
        let cal = Calendar.current
        var comps = cal.dateComponents([.year,.month,.day], from: Date())
        comps.hour = 22; comps.minute = 30; comps.second = 0
        let now = cal.date(from: comps)!
        XCTAssertEqual(service.calculateEarliestBeginDate(now: now), now)
    }

    func testCalculateEarliestBeginDate_After2359() {
        // 00:10 next day -> expect tomorrow 22:01 vs the date basis
        let cal = Calendar.current
        let base = Date()
        var comps = cal.dateComponents([.year,.month,.day], from: base)
        // simulate 00:10 of the next day
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: base)) {
            var t = cal.dateComponents([.year,.month,.day], from: tomorrow)
            t.hour = 0; t.minute = 10; t.second = 0
            let now = cal.date(from: t)!
            let expected = cal.date(bySettingHour: 22, minute: 1, second: 0, of: now)!
            XCTAssertEqual(service.calculateEarliestBeginDate(now: now), expected)
        } else {
            XCTFail("Failed to compute tomorrow date")
        }
    }

    func testSafeEarliestBeginDate_Respects20MinMinimum() {
        let cal = Calendar.current
        let now = Date()
        let withinWindow = now.addingTimeInterval(5 * 60) // would be < 20 minutes
        // Force calculateEarliestBeginDate(now:) to return withinWindow by crafting date in 22:01-23:59 interval
        // but here we directly test min clamp
        let clamped = service.safeEarliestBeginDate(now: withinWindow)
        XCTAssertGreaterThanOrEqual(clamped.timeIntervalSince(now), 20 * 60 - 1)
    }
}
