import XCTest
@testable import LazyBones
import UserNotifications

final class NotificationIntegrationTests: XCTestCase {
    // Реальный сервис уведомлений c перехватом вызовов для интеграции с менеджером
    private final class InterceptingNotificationService: NotificationService {
        struct Call { let title: String; let body: String; let hour: Int; let minute: Int; let identifier: String }
        var repeatingCalls: [Call] = []
        var cancelAllCalled = 0
        var checkPermissionCalled = 0
        var debugCalled = 0
        override func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws {
            repeatingCalls.append(.init(title: title, body: body, hour: hour, minute: minute, identifier: identifier))
        }
        override func cancelAllNotifications() async throws {
            cancelAllCalled += 1
        }
        override func checkNotificationPermission() async -> Bool {
            checkPermissionCalled += 1
            return true
        }
        override func debugNotificationStatus() async {
            debugCalled += 1
        }
    }

    private final class MockUserDefaults: UserDefaultsManagerProtocol {
        private var enabled = false
        private var interval = 1
        private var start = 8
        private var end = 22
        private var mode = "hourly"
        func set<T>(_ value: T, forKey key: String) {}
        func get<T>(_ type: T.Type, forKey key: String) -> T? { nil }
        func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { defaultValue }
        func remove(forKey key: String) {}
        func hasValue(forKey key: String) -> Bool { false }
        func bool(forKey key: String) -> Bool { false }
        func string(forKey key: String) -> String? { nil }
        func integer(forKey key: String) -> Int { 0 }
        func data(forKey key: String) -> Data? { nil }
        func loadPosts() -> [Post] { [] }
        func savePosts(_ posts: [Post]) {}
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {}
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) { (nil, nil, nil) }
        func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
            self.enabled = enabled; self.interval = intervalHours; self.start = startHour; self.end = endHour; self.mode = mode
        }
        func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
            (enabled, interval, start, end, mode)
        }
    }

    private var manager: NotificationManagerService!
    private var service: InterceptingNotificationService!
    private var defaults: MockUserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        service = InterceptingNotificationService(notificationCenter: .current())
        defaults = MockUserDefaults()
        manager = NotificationManagerService(userDefaultsManager: defaults, notificationService: service)
    }

    override func tearDown() async throws {
        manager = nil
        service = nil
        defaults = nil
        try await super.tearDown()
    }

    func testDisabled_DoesNotScheduleOrCancel() {
        // Given
        manager.notificationsEnabled = false
        // When
        manager.scheduleNotifications()
        // Then
        XCTAssertEqual(service.cancelAllCalled, 0)
        XCTAssertEqual(service.repeatingCalls.count, 0)
        XCTAssertEqual(service.checkPermissionCalled, 0)
    }

    func testEnabledHourly_ValidParams_Schedules() {
        // Given
        manager.notificationsEnabled = true
        manager.notificationMode = .hourly
        manager.notificationIntervalHours = 2
        manager.notificationStartHour = 9
        manager.notificationEndHour = 11
        // When
        manager.scheduleNotifications()
        // Then
        XCTAssertEqual(service.cancelAllCalled, 1)
        XCTAssertGreaterThanOrEqual(service.checkPermissionCalled, 1)
        XCTAssertEqual(service.repeatingCalls.count, 3) // 9,10,11
        let ids = Set(service.repeatingCalls.map { $0.identifier })
        XCTAssertTrue(ids.contains("report_reminder_hourly_9"))
        XCTAssertTrue(ids.contains("report_reminder_hourly_10"))
        XCTAssertTrue(ids.contains("report_reminder_hourly_11"))
    }

    func testEnabled_InvalidHours_EarlyExitByValidation_NoSchedules() {
        // Given
        manager.notificationsEnabled = true
        manager.notificationMode = .hourly
        manager.notificationIntervalHours = 1
        manager.notificationStartHour = -1
        manager.notificationEndHour = 30
        // When
        manager.scheduleNotifications()
        // Then
        XCTAssertEqual(service.cancelAllCalled, 1) // cancel before schedule attempt
        XCTAssertGreaterThanOrEqual(service.checkPermissionCalled, 1)
        XCTAssertEqual(service.repeatingCalls.count, 0)
    }
}
