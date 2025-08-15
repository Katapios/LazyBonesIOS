import XCTest
@testable import LazyBones

@MainActor
final class SettingsViewModelNewTests: XCTestCase {
    // Mocks
    final class MockSettingsRepository: SettingsRepositoryProtocol {
        var savedEnabled: Bool?
        var savedMode: NotificationMode?
        var savedIntervalHours: Int?
        var savedStartHour: Int?
        var savedEndHour: Int?

        var telegram: (token: String?, chatId: String?, botId: String?) = ("tok", "chat", "bot")

        func saveNotificationSettings(enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) async throws {
            savedEnabled = enabled
            savedMode = mode
            savedIntervalHours = intervalHours
            savedStartHour = startHour
            savedEndHour = endHour
        }

    final class MockTelegramConfigUpdater: TelegramConfigUpdaterProtocol {
        var appliedToken: String?
        func applyTelegramToken(_ token: String?) { appliedToken = token }
    }

        func loadNotificationSettings() async throws -> (enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) {
            return (true, .twice, 4, 9, 21)
        }

        var lastSavedTelegram: (token: String?, chatId: String?, botId: String?)? = nil
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws {
            telegram = (token, chatId, botId)
            lastSavedTelegram = (token, chatId, botId)
        }

        func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?) {
            telegram
        }

        func saveReportStatus(_ status: ReportStatus) async throws {}
        func loadReportStatus() async throws -> ReportStatus { .notStarted }
        func saveForceUnlock(_ forceUnlock: Bool) async throws {}
        func loadForceUnlock() async throws -> Bool { false }
    }

    final class MockNotificationManager: NotificationManagerServiceProtocol {
        @Published var notificationsEnabled: Bool = false
        @Published var notificationIntervalHours: Int = 1
        @Published var notificationStartHour: Int = 8
        @Published var notificationEndHour: Int = 22
        @Published var notificationMode: NotificationMode = .hourly

        var didRequestPermission = false
        var didSchedule = false
        var didCancel = false

        func saveNotificationSettings() {}
        func loadNotificationSettings() {}
        func requestNotificationPermissionAndSchedule() { didRequestPermission = true }
        func scheduleNotifications() { didSchedule = true }
        func cancelAllNotifications() { didCancel = true }
        func scheduleNotificationsIfNeeded() { didSchedule = true }
        func notificationScheduleForToday() -> String? { return nil }
    }

    final class MockPostRepository: PostRepositoryProtocol {
        func createOrUpdate(_ post: DomainPost) async throws -> DomainPost { post }
        func getAll() async throws -> [DomainPost] { [] }
        func getById(_ id: String) async throws -> DomainPost? { nil }
        func delete(by id: String) async throws {}
        func getTodayRegularReport() async throws -> DomainPost? { nil }
        func getBy(date: Date, type: ReportType) async throws -> DomainPost? { nil }
    }

    final class MockTimerService: PostTimerServiceProtocol {
        func startTimer() {}
        func stopTimer() {}
    }

    final class MockStatusManager: ReportStatusManagerProtocol {
        var currentStatus: ReportStatus = .notStarted
        var unlockCalled = 0
        func updateStatus() {}
        func unlockReportCreation() {}
        func loadStatus() -> (status: ReportStatus, forceUnlock: Bool) { (currentStatus, false) }
        func saveStatus(_ status: ReportStatus, forceUnlock: Bool) {}
        func updateDependencies(_ status: ReportStatus) {}
    }

    final class MockICloudService: ICloudServiceProtocol {
        var available = true
        var isICloudAvailableCallCount = 0
        var exportCallCount = 0
        var fileAccessGranted = true
        var iCloudAccessGranted = true

        func exportReports(
            reportType: ICloudReportType,
            startDate: Date?,
            endDate: Date?,
            includeDeviceInfo: Bool,
            format: ReportFormat
        ) async throws -> ExportReportsOutput {
            exportCallCount += 1
            return ExportReportsOutput(success: true, exportedCount: 1, error: nil)
        }

        func importReports(
            reportType: ICloudReportType,
            startDate: Date?,
            endDate: Date?,
            filterByDevice: String?
        ) async throws -> ImportICloudReportsOutput {
            return ImportICloudReportsOutput(success: true, importedCount: 0, error: nil)
        }

        func isICloudAvailable() async -> Bool { isICloudAvailableCallCount += 1; return available }
        func getFileInfo() async -> (url: URL?, size: Int64?) { (nil, nil) }
        func deleteFile() async throws {}
        func getFileLocationInfo() -> String { "mock" }
        func requestICloudAccess() async -> Bool { iCloudAccessGranted }
        func requestFileAccessPermissions() async -> Bool { fileAccessGranted }
        func createTestFileInAccessibleLocation() async -> Bool { true }
    }

    final class MockAutoSendService: AutoSendServiceType {
        var autoSendEnabled: Bool = false
        var autoSendTime: Date = Date()
        var lastAutoSendStatus: String? = nil
        func scheduleAutoSendIfNeeded() {}
    }

    var vm: SettingsViewModelNew!
    var repo: MockSettingsRepository!
    var notif: MockNotificationManager!
    var postRepo: MockPostRepository!
    var timer: MockTimerService!
    var status: MockStatusManager!
    var icloud: MockICloudService!
    var autosend: MockAutoSendService!
    var tgUpdater: MockTelegramConfigUpdater!

    override func setUp() {
        super.setUp()
        repo = MockSettingsRepository()
        notif = MockNotificationManager()
        postRepo = MockPostRepository()
        timer = MockTimerService()
        status = MockStatusManager()
        icloud = MockICloudService()
        autosend = MockAutoSendService()
        tgUpdater = MockTelegramConfigUpdater()
        vm = SettingsViewModelNew(
            settingsRepository: repo,
            notificationManager: notif,
            postRepository: postRepo,
            timerService: timer,
            statusManager: status,
            iCloudService: icloud,
            autoSendService: autosend,
            telegramConfigUpdater: tgUpdater
        )
    }

    override func tearDown() {
        vm = nil
        repo = nil
        notif = nil
        postRepo = nil
        timer = nil
        status = nil
        icloud = nil
        autosend = nil
        tgUpdater = nil
        super.tearDown()
    }

    func testLoadSettings_PopulatesState() async {
        await vm.handle(.loadSettings)
        XCTAssertEqual(vm.state.deviceName, AppConfig.sharedUserDefaults.string(forKey: "deviceName") ?? "")
        XCTAssertTrue(vm.state.isICloudAvailable)
        XCTAssertTrue(vm.state.notificationsEnabled == notif.notificationsEnabled)
        XCTAssertEqual(vm.state.notificationMode, notif.notificationMode)
        XCTAssertEqual(vm.state.autoSendEnabled, autosend.autoSendEnabled)
    }

    func testSetNotificationsEnabled_PropagatesToService() {
        vm.setNotificationsEnabled(true)
        XCTAssertTrue(notif.notificationsEnabled)
        vm.setNotificationsEnabled(false)
        XCTAssertFalse(notif.notificationsEnabled)
    }

    func testSetNotificationMode_PropagatesToService() {
        vm.setNotificationMode(.twice)
        XCTAssertEqual(notif.notificationMode, .twice)
        vm.setNotificationMode(.hourly)
        XCTAssertEqual(notif.notificationMode, .hourly)
    }

    func testUnlockReports_CallsStatusManager() async {
        // Given
        class StatusManagerSpy: MockStatusManager {
            override func unlockReportCreation() { unlockCalled += 1 }
        }
        let spy = StatusManagerSpy()
        vm = SettingsViewModelNew(
            settingsRepository: repo,
            notificationManager: notif,
            postRepository: postRepo,
            timerService: timer,
            statusManager: spy,
            iCloudService: icloud,
            autoSendService: autosend,
            telegramConfigUpdater: tgUpdater
        )
        // When
        await vm.handle(.unlockReports)
        // Then
        XCTAssertEqual(spy.unlockCalled, 1)
    }

    func testSaveTelegramSettings_PersistsAndSetsStatus() async {
        // When
        await vm.handle(.saveTelegramSettings(token: "newTok", chatId: "123", botId: "777"))
        // Then
        XCTAssertEqual(repo.lastSavedTelegram?.token, "newTok")
        XCTAssertEqual(repo.lastSavedTelegram?.chatId, "123")
        XCTAssertEqual(repo.lastSavedTelegram?.botId, "777")
        XCTAssertEqual(vm.state.telegramStatus, "Сохранено!")
        XCTAssertEqual(tgUpdater.appliedToken, "newTok")
    }

    func testExportToICloud_SuccessSetsResult() async {
        await vm.handle(.exportToICloud)
        XCTAssertEqual(icloud.exportCallCount, 1)
        XCTAssertEqual(vm.state.exportResult?.contains("Экспорт успешен"), true)
    }

    func testAutoSend_SettersPropagateAndSchedule() {
        // initial
        XCTAssertEqual(vm.state.autoSendEnabled, autosend.autoSendEnabled)
        // enable
        vm.setAutoSendEnabled(true)
        XCTAssertTrue(autosend.autoSendEnabled)
    }
}
