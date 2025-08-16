import XCTest
import Combine
import UserNotifications
@testable import LazyBones

final class PostStorePublishTests: XCTestCase {
    // Mocks (prefixed to avoid collisions)
    final class PSP_MockPostTelegramService: PostTelegramServiceProtocol {
        var lastText: String?
        var sendTextResult: Bool = true
        func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
            lastText = text
            completion(sendTextResult)
        }
        func performAutoSendReport(completion: (() -> Void)?) { completion?() }
        func autoSendAllReportsForToday() {}
        func sendUnsentReportsFromPreviousDays() {}
    }

    final class PSP_MockTelegramService: TelegramServiceProtocol {
        struct Call { let url: URL; let chatId: String }
        var sendVoiceCalls: [Call] = []
        var sendVoiceShouldThrow: Bool = false

        func sendMessage(_ text: String, to chatId: String) async throws {}
        func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws {}
        func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws {
            if sendVoiceShouldThrow { throw NSError(domain: "test", code: -1) }
            sendVoiceCalls.append(.init(url: fileURL, chatId: chatId))
        }
        func getUpdates(offset: Int?) async throws -> [LazyBones.TelegramUpdate] { return [] }
        func getMe() async throws -> LazyBones.TelegramUser { return TelegramUser(id: 0, isBot: true, firstName: "bot", lastName: nil, username: nil) }
        func downloadFile(_ fileId: String) async throws -> Data { return Data() }
    }

    final class PSP_MockFileChecker: FileExistenceChecking {
        private let existing: Set<String>
        init(existing: Set<String>) { self.existing = existing }
        func exists(atPath path: String) -> Bool { existing.contains(path) }
    }

    // Minimal stubs to satisfy PostStore.init guard
    final class PSP_StubPostNotificationService: PostNotificationServiceProtocol {
        func scheduleNotifications() {}
        func cancelAllNotifications() {}
        func cancelNotification(identifier: String) {}
        func getPendingNotifications() async -> [UNNotificationRequest] { [] }
        func getDeliveredNotifications() async -> [UNNotification] { [] }
        func scheduleNotificationsIfNeeded() {}
    }
    final class PSP_StubNotificationManagerService: NotificationManagerServiceProtocol {
        // ObservableObject conformance
        let objectWillChange = PassthroughSubject<Void, Never>()
        // Required properties
        var notificationsEnabled: Bool = false
        var notificationIntervalHours: Int = 1
        var notificationStartHour: Int = 8
        var notificationEndHour: Int = 22
        var notificationMode: NotificationMode = .hourly
        // Required methods
        func saveNotificationSettings() {}
        func loadNotificationSettings() {}
        func requestNotificationPermissionAndSchedule() {}
        func scheduleNotifications() {}
        func cancelAllNotifications() {}
        func scheduleNotificationsIfNeeded() {}
        func notificationScheduleForToday() -> String? { nil }
    }
    final class PSP_StubTelegramIntegrationService: TelegramIntegrationServiceProtocol {
        // ObservableObject conformance
        let objectWillChange = PassthroughSubject<Void, Never>()
        // Published properties
        var externalPosts: [Post] = []
        var telegramToken: String? = nil
        var telegramChatId: String? = nil
        var telegramBotId: String? = nil
        var lastUpdateId: Int? = nil
        // Methods
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {}
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) { (nil, nil, nil) }
        func saveLastUpdateId(_ updateId: Int) { lastUpdateId = updateId }
        func resetLastUpdateId() { lastUpdateId = nil }
        func refreshTelegramService() {}
        func fetchExternalPosts(completion: @escaping (Bool) -> Void) { completion(true) }
        func saveExternalPosts() {}
        func loadExternalPosts() { externalPosts = [] }
        func deleteBotMessages(completion: @escaping (Bool) -> Void) { completion(true) }
        func deleteAllBotMessages(completion: @escaping (Bool) -> Void) { completion(true) }
        func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? { nil }
        func getAllPosts() -> [Post] { externalPosts }
        func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String { "" }
    }
    final class PSP_StubAutoSendService: AutoSendServiceProtocol {
        // ObservableObject conformance
        let objectWillChange = PassthroughSubject<Void, Never>()
        // Properties
        var autoSendEnabled: Bool = false
        var autoSendTime: Date = Date()
        var lastAutoSendStatus: String? = nil
        // Methods
        func loadAutoSendSettings() {}
        func saveAutoSendSettings() {}
        func scheduleAutoSendIfNeeded() {}
        func performAutoSendReport() {}
        func performAutoSendReport(completion: (() -> Void)?) { completion?() }
        func autoSendAllReportsForToday(completion: (() -> Void)? = nil) { completion?() }
    }

    // Helpers
    private func registerDependencies(postService: PSP_MockPostTelegramService, telegramService: PSP_MockTelegramService, fileChecker: FileExistenceChecking? = nil) {
        let dc = DependencyContainer.shared
        // Чистим контейнер, чтобы избежать прежних регистраций
        dc.clear()
        // Базовые зависимости
        dc.register(UserDefaultsManager.self, instance: UserDefaultsManager.shared)
        dc.register(PostNotificationServiceProtocol.self, instance: PSP_StubPostNotificationService())
        dc.register(NotificationManagerServiceType.self, instance: PSP_StubNotificationManagerService())
        dc.register(TelegramIntegrationServiceType.self, instance: PSP_StubTelegramIntegrationService())
        dc.register(AutoSendServiceType.self, instance: PSP_StubAutoSendService())
        // Регистрируем моки
        if let fileChecker { dc.register(FileExistenceChecking.self, instance: fileChecker) }
        dc.register(PostTelegramServiceProtocol.self) { postService }
        dc.register(TelegramServiceProtocol.self) { telegramService }
        // Остальные зависимости дадут фолбэк внутри PostStore.init
    }

    private func createTempFile(named: String) -> String {
        // Используем Documents каталога приложения, чтобы исключить различия контейнеров tmp
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(named)
        do {
            try Data("test".utf8).write(to: url, options: .atomic)
        } catch {
            _ = FileManager.default.createFile(atPath: url.path, contents: Data("test".utf8), attributes: nil)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: Data("test".utf8), attributes: nil)
        }
        return url.path
    }

    // MARK: - Tests
    func testPublish_TextOnly_Succeeds() {
        // arrange
        let postService = PSP_MockPostTelegramService()
        let tgService = PSP_MockTelegramService()
        registerDependencies(postService: postService, telegramService: tgService)
        UserDefaultsManager.shared.set("chat123", forKey: "telegramChatId")
        let store = PostStore()

        // act
        let exp = expectation(description: "publish")
        store.publish(text: "Hello", voicePaths: []) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        XCTAssertEqual(postService.lastText, "Hello")
        XCTAssertTrue(tgService.sendVoiceCalls.isEmpty)
    }

    func testPublish_WithValidVoices_AllSuccess() {
        let postService = PSP_MockPostTelegramService()
        let tgService = PSP_MockTelegramService()
        UserDefaultsManager.shared.set("chat123", forKey: "telegramChatId")
        let p1 = createTempFile(named: "v1.ogg")
        let p2 = createTempFile(named: "v2.ogg")
        let checker = PSP_MockFileChecker(existing: [p1, p2])
        registerDependencies(postService: postService, telegramService: tgService, fileChecker: checker)
        let store = PostStore()

        let exp = expectation(description: "publish")
        store.publish(text: "T", voicePaths: [p1, p2]) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(tgService.sendVoiceCalls.count, 2)
        XCTAssertEqual(tgService.sendVoiceCalls.map { $0.url.path }.sorted(), [p1, p2].sorted())
        XCTAssertTrue(tgService.sendVoiceCalls.allSatisfy { $0.chatId == "chat123" })
    }

    func testPublish_WithMissingVoice_IsFilteredAndSucceeds() {
        let postService = PSP_MockPostTelegramService()
        let tgService = PSP_MockTelegramService()
        UserDefaultsManager.shared.set("chat123", forKey: "telegramChatId")
        let existing = createTempFile(named: "exists.ogg")
        let missing = "/tmp/does_not_exist.ogg"
        let checker = PSP_MockFileChecker(existing: [existing])
        registerDependencies(postService: postService, telegramService: tgService, fileChecker: checker)
        let store = PostStore()

        let exp = expectation(description: "publish")
        store.publish(text: "T", voicePaths: [existing, missing]) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(tgService.sendVoiceCalls.count, 1)
        XCTAssertEqual(tgService.sendVoiceCalls.first?.url.path, existing)
    }

    func testPublish_VoiceSendFails_ReturnsFalse() {
        let postService = PSP_MockPostTelegramService()
        let tgService = PSP_MockTelegramService()
        tgService.sendVoiceShouldThrow = true
        UserDefaultsManager.shared.set("chat123", forKey: "telegramChatId")
        let p1 = createTempFile(named: "v_fail.ogg")
        let checker = PSP_MockFileChecker(existing: [p1])
        registerDependencies(postService: postService, telegramService: tgService, fileChecker: checker)
        let store = PostStore()

        let exp = expectation(description: "publish")
        store.publish(text: "T", voicePaths: [p1]) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
        XCTAssertEqual(tgService.sendVoiceCalls.count, 0)
    }
}
