import XCTest
@testable import LazyBones

@MainActor
final class SettingsViewModelNewTests: XCTestCase {
    // Mocks
    fileprivate final class MockSettingsRepository: SettingsRepositoryProtocol {
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

    fileprivate final class MockTelegramConfigUpdater: TelegramConfigUpdaterProtocol {
        var appliedToken: String?
        func applyTelegramToken(_ token: String?) { appliedToken = token }
    }

    fileprivate final class MockNotificationManager: NotificationManagerServiceProtocol {
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

    fileprivate final class MockPostRepository: PostRepositoryProtocol {
        var storage: [DomainPost] = []
        func save(_ post: DomainPost) async throws {
            if let idx = storage.firstIndex(where: { $0.id == post.id }) {
                storage[idx] = post
            } else {
                storage.append(post)
            }
        }
        func fetch() async throws -> [DomainPost] { storage }
        func fetch(for date: Date) async throws -> [DomainPost] {
            let cal = Calendar.current
            return storage.filter { cal.isDate($0.date, inSameDayAs: date) }
        }
        func update(_ post: DomainPost) async throws {
            if let idx = storage.firstIndex(where: { $0.id == post.id }) {
                storage[idx] = post
            }
        }
        func delete(_ post: DomainPost) async throws { storage.removeAll { $0.id == post.id } }
        func clear() async throws { storage.removeAll() }
    }

    fileprivate final class MockTimerService: PostTimerServiceProtocol {
        var timeLeft: String = ""
        var timeProgress: Double = 0
        func startTimer() {}
        func stopTimer() {}
        func updateTimeLeft() {}
        func updateReportStatus(_ status: ReportStatus) {}
    }

    fileprivate class MockStatusManager: ReportStatusManagerProtocol {
        @Published var reportStatus: ReportStatus = .notStarted
        @Published var forceUnlock: Bool = false
        @Published var currentDay: Date = Calendar.current.startOfDay(for: Date())

        var unlockCalled = 0

        func updateStatus() {}
        func checkForNewDay() {}
        func unlockReportCreation() { unlockCalled += 1 }
        func loadStatus() {}
        func saveStatus() {}
    }

    fileprivate final class MockICloudService: ICloudServiceProtocol {
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

    fileprivate final class MockAutoSendService: AutoSendServiceProtocol {
        @Published var autoSendEnabled: Bool = false
        @Published var autoSendTime: Date = Date()
        @Published var lastAutoSendStatus: String? = nil
        func loadAutoSendSettings() {}
        func saveAutoSendSettings() {}
        func scheduleAutoSendIfNeeded() {}
        func performAutoSendReport() {}
        func performAutoSendReport(completion: (() -> Void)?) { completion?() }
        func autoSendAllReportsForToday(completion: (() -> Void)?) { completion?() }
    }

    fileprivate final class MockTelegramResolver: TelegramServiceResolverProtocol {
        var service: TelegramServiceProtocol?
        func resolveTelegramService() -> TelegramServiceProtocol? { service }
    }

    fileprivate final class MockLegacyUISync: LegacyUISyncProtocol {
        var syncCalls = 0
        var savedForceUnlock: Bool?
        func syncReportStatusToLegacyUI() { syncCalls += 1 }
        func saveForceUnlock(_ value: Bool) { savedForceUnlock = value }
    }

    fileprivate var vm: SettingsViewModelNew!
    fileprivate var repo: MockSettingsRepository!
    fileprivate var notif: MockNotificationManager!
    fileprivate var postRepo: MockPostRepository!
    fileprivate var timer: MockTimerService!
    fileprivate var status: MockStatusManager!
    fileprivate var icloud: MockICloudService!
    fileprivate var autosend: MockAutoSendService!
    fileprivate var tgUpdater: MockTelegramConfigUpdater!
    fileprivate var tgResolver: MockTelegramResolver!
    fileprivate var legacySync: MockLegacyUISync!

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
        tgResolver = MockTelegramResolver()
        legacySync = MockLegacyUISync()
        vm = SettingsViewModelNew(
            settingsRepository: repo,
            notificationManager: notif,
            postRepository: postRepo,
            timerService: timer,
            statusManager: status,
            iCloudService: icloud,
            autoSendService: autosend,
            telegramConfigUpdater: tgUpdater,
            telegramResolver: tgResolver,
            legacyUISync: legacySync
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
        tgResolver = nil
        legacySync = nil
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
        tgResolver = MockTelegramResolver()
        legacySync = MockLegacyUISync()
        vm = SettingsViewModelNew(
            settingsRepository: repo,
            notificationManager: notif,
            postRepository: postRepo,
            timerService: timer,
            statusManager: spy,
            iCloudService: icloud,
            autoSendService: autosend,
            telegramConfigUpdater: tgUpdater,
            telegramResolver: tgResolver,
            legacyUISync: legacySync
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

// MARK: - Telegram connection tests

extension SettingsViewModelNewTests {
    // Local mock for TelegramService to control behaviors
    private final class TGMockService: TelegramServiceProtocol {
        enum Mode { case success, invalidToken, invalidChat }
        var mode: Mode = .success
        var sentMessages: [(text: String, chatId: String)] = []
        func getMe() async throws -> TelegramUser {
            switch mode {
            case .success: return TelegramUser(id: 1, isBot: true, firstName: "bot", lastName: nil, username: "lazybones_bot")
            case .invalidToken: throw TelegramServiceError.invalidToken
            case .invalidChat: return TelegramUser(id: 1, isBot: true, firstName: "bot", lastName: nil, username: "lazybones_bot")
            }
        }
        func sendMessage(_ text: String, to chatId: String) async throws {
            switch mode {
            case .success:
                sentMessages.append((text, chatId))
            case .invalidToken:
                throw TelegramServiceError.invalidToken
            case .invalidChat:
                throw TelegramServiceError.invalidChatId
            }
        }
        func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws { }
        func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws { }
        func getUpdates(offset: Int?) async throws -> [TelegramUpdate] { return [] }
        func downloadFile(_ fileId: String) async throws -> Data { Data() }
    }

    func testCheckTelegramConnection_SuccessUpdatesStatus() async {
        // Given
        let tg = TGMockService()
        tg.mode = .success
        tgResolver.service = tg
        vm.state.telegramToken = "tok"
        vm.state.telegramChatId = "123"

        // When
        await vm.handle(.checkTelegramConnection)

        // Then
        XCTAssertEqual(vm.state.telegramStatus, "Успешно!")
    }

    func testCheckTelegramConnection_InvalidTokenSetsMessage() async {
        // Given
        let tg = TGMockService()
        tg.mode = .invalidToken
        tgResolver.service = tg
        vm.state.telegramToken = "bad"
        vm.state.telegramChatId = "123"

        // When
        await vm.handle(.checkTelegramConnection)

        // Then
        XCTAssertEqual(vm.state.telegramStatus, "Ошибка: неверный токен")
    }

    func testCheckTelegramConnection_InvalidChatIdSetsMessage() async {
        // Given
        let tg = TGMockService()
        tg.mode = .invalidChat
        tgResolver.service = tg
        vm.state.telegramToken = "tok"
        vm.state.telegramChatId = "badChat"

        // When
        await vm.handle(.checkTelegramConnection)

        // Then
        XCTAssertEqual(vm.state.telegramStatus, "Ошибка: неверный chat_id")
    }

    func testCheckTelegramConnection_RegistersServiceIfNil() async {
        // Given resolver initially returns nil
        tgResolver.service = nil
        vm.state.telegramToken = "tok"
        vm.state.telegramChatId = "123"

        // Custom updater that registers service on apply (no subclassing of finals)
        final class RegisteringUpdater: TelegramConfigUpdaterProtocol {
            weak var resolver: MockTelegramResolver?
            var appliedToken: String?
            func applyTelegramToken(_ token: String?) {
                appliedToken = token
                if let r = resolver {
                    let s = TGMockService()
                    s.mode = .success
                    r.service = s
                }
            }
        }

        let registeringUpdater = RegisteringUpdater()
        registeringUpdater.resolver = tgResolver

        // Recreate VM with registering updater
        vm = SettingsViewModelNew(
            settingsRepository: repo,
            notificationManager: notif,
            postRepository: postRepo,
            timerService: timer,
            statusManager: status,
            iCloudService: icloud,
            autoSendService: autosend,
            telegramConfigUpdater: registeringUpdater,
            telegramResolver: tgResolver,
            legacyUISync: legacySync
        )

        // Important: after recreating VM, state was reset
        vm.state.telegramToken = "tok"
        vm.state.telegramChatId = "123"

        // When
        await vm.handle(.checkTelegramConnection)

        // Then
        XCTAssertEqual(vm.state.telegramStatus, "Успешно!")
        XCTAssertEqual(registeringUpdater.appliedToken, "tok")
    }
}

