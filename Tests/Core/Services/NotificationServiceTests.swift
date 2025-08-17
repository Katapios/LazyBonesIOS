import XCTest
@testable import LazyBones
import UserNotifications

final class NotificationServiceTests: XCTestCase {
    // Subclass to intercept internal scheduling without hitting system APIs
    private final class TestableNotificationService: NotificationService {
        struct Call { let title: String; let body: String; let hour: Int; let minute: Int; let identifier: String }
        var repeatingCalls: [Call] = []
        var cancelAllCalled = 0
        override func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws {
            repeatingCalls.append(.init(title: title, body: body, hour: hour, minute: minute, identifier: identifier))
        }
        override func cancelAllNotifications() async throws {
            cancelAllCalled += 1
        }
    }

    private var service: TestableNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        service = TestableNotificationService(notificationCenter: .current())
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Validation tests

    func testScheduleReportNotifications_InvalidHours_OutOfRange() async throws {
        try await service.scheduleReportNotifications(enabled: true, intervalHours: 1, startHour: -1, endHour: 24, mode: "hourly")
        XCTAssertEqual(service.repeatingCalls.count, 0)
        XCTAssertEqual(service.cancelAllCalled, 1) // cancel happens before validation
    }

    func testScheduleReportNotifications_StartGreaterThanEnd() async throws {
        try await service.scheduleReportNotifications(enabled: true, intervalHours: 1, startHour: 10, endHour: 9, mode: "hourly")
        XCTAssertEqual(service.repeatingCalls.count, 0)
        XCTAssertEqual(service.cancelAllCalled, 1)
    }

    func testScheduleReportNotifications_HourlyInvalidInterval() async throws {
        try await service.scheduleReportNotifications(enabled: true, intervalHours: 0, startHour: 9, endHour: 10, mode: "hourly")
        XCTAssertEqual(service.repeatingCalls.count, 0)
        XCTAssertEqual(service.cancelAllCalled, 1)
    }

    // MARK: - Happy paths

    func testScheduleReportNotifications_Hourly_ValidSchedulesEachHour() async throws {
        try await service.scheduleReportNotifications(enabled: true, intervalHours: 2, startHour: 9, endHour: 11, mode: "hourly")
        // Our implementation schedules every hour in range, intervalHours used by manager for cadence semantics
        XCTAssertEqual(service.repeatingCalls.count, 3) // 9,10,11
        let hours = service.repeatingCalls.map { $0.hour }.sorted()
        XCTAssertEqual(hours, [9,10,11])
        // Check identifiers format
        let ids = Set(service.repeatingCalls.map { $0.identifier })
        XCTAssertTrue(ids.contains("report_reminder_hourly_9"))
        XCTAssertTrue(ids.contains("report_reminder_hourly_10"))
        XCTAssertTrue(ids.contains("report_reminder_hourly_11"))
    }

    func testScheduleReportNotifications_Twice_ValidSchedulesTwo() async throws {
        try await service.scheduleReportNotifications(enabled: true, intervalHours: 3, startHour: 8, endHour: 20, mode: "twice")
        XCTAssertEqual(service.repeatingCalls.count, 2)
        let ids = Set(service.repeatingCalls.map { $0.identifier })
        XCTAssertTrue(ids.contains("report_reminder_morning"))
        XCTAssertTrue(ids.contains("report_reminder_evening"))
        // Evening fixed at 21:00
        let evening = service.repeatingCalls.first(where: { $0.identifier == "report_reminder_evening" })
        XCTAssertEqual(evening?.hour, 21)
        XCTAssertEqual(evening?.minute, 0)
    }
}
