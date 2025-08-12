import XCTest
@testable import LazyBones

final class MainViewModelTimerTests: XCTestCase {
    // MARK: - Local Mocks
    final class MVM_UserDefaultsMock: UserDefaultsManagerProtocol {
        var enabled: Bool = true
        var intervalHours: Int = 1
        var startHour: Int = 8
        var endHour: Int = 22
        var mode: String = "hourly"
        
        func set<T>(_ value: T, forKey key: String) {}
        func get<T>(_ type: T.Type, forKey key: String) -> T? { return nil }
        func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { return defaultValue }
        func remove(forKey key: String) {}
        func hasValue(forKey key: String) -> Bool { return false }
        func bool(forKey key: String) -> Bool { return false }
        func string(forKey key: String) -> String? { return nil }
        func integer(forKey key: String) -> Int { return 0 }
        func data(forKey key: String) -> Data? { return nil }
        func loadPosts() -> [Post] { return [] }
        func savePosts(_ posts: [Post]) {}
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {}
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) { return (nil, nil, nil) }
        func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
            self.enabled = enabled
            self.intervalHours = intervalHours
            self.startHour = startHour
            self.endHour = endHour
            self.mode = mode
        }
        func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
            return (enabled, intervalHours, startHour, endHour, mode)
        }
    }
    
    final class MVM_PostTelegramServiceMock: PostTelegramServiceProtocol {
        func publishPostToTelegram(_ post: Post, deviceName: String, completion: @escaping (Bool) -> Void) { completion(true) }
        func isTelegramConfigured() -> Bool { return false }
    }
    
    final class MVM_PostNotificationServiceMock: PostNotificationServiceProtocol {
        func scheduleNotifications() {}
        func scheduleNotificationsIfNeeded() {}
        func cancelAllNotifications() {}
        func cancelNotification(identifier: String) {}
        func getPendingNotifications() async -> [UNNotificationRequest] { return [] }
        func getDeliveredNotifications() async -> [UNNotification] { return [] }
    }
    
    final class MVM_NotificationManagerServiceMock: NotificationManagerServiceType {
        func requestNotificationPermissionAndSchedule() {}
        func refreshScheduledNotifications() {}
        func updateIfSettingsChanged() {}
    }
    
    final class MVM_TelegramIntegrationServiceMock: TelegramIntegrationServiceType {
        var externalPosts: [Post] = []
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {}
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) { return (nil, nil, nil) }
        func fetchExternalPosts(completion: @escaping (Bool) -> Void) { completion(true) }
        func deleteAllBotMessages(completion: @escaping (Bool) -> Void) { completion(true) }
        func refreshTelegramService() {}
        func resetLastUpdateId() {}
        func getAllPosts() -> [Post] { return [] }
        func saveExternalPosts() {}
        func loadExternalPosts() {}
        func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? { return nil }
        func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String { return "" }
    }
    
    final class MVM_AutoSendServiceMock: AutoSendServiceType {
        func loadAutoSendSettings() {}
        func scheduleAutoSendIfNeeded() {}
    }

    // MARK: - Helpers
    private func registerDependencies(udm: MVM_UserDefaultsMock) {
        let dc = DependencyContainer.shared
        dc.register(UserDefaultsManager.self) { _ in UserDefaultsManager.shared } // not used directly
        dc.register(UserDefaultsManagerProtocol.self) { _ in udm }
        dc.register(PostTelegramServiceProtocol.self) { _ in MVM_PostTelegramServiceMock() }
        dc.register(PostNotificationServiceProtocol.self) { _ in MVM_PostNotificationServiceMock() }
        dc.register(NotificationManagerServiceType.self) { _ in MVM_NotificationManagerServiceMock() }
        dc.register(TelegramIntegrationServiceType.self) { _ in MVM_TelegramIntegrationServiceMock() }
        dc.register(AutoSendServiceType.self) { _ in MVM_AutoSendServiceMock() }
    }
    
    // MARK: - Tests
    func test_timer_beforeStart() {
        let udm = MVM_UserDefaultsMock()
        let nowHour = Calendar.current.component(.hour, from: Date())
        udm.startHour = ((nowHour + 2) % 24)
        udm.endHour = ((nowHour + 3) % 24)
        registerDependencies(udm: udm)
        
        let store = PostStore()
        let vm = MainViewModel(store: store)
        vm.currentTime = Date()
        
        XCTAssertEqual(vm.timerLabel, "До старта")
        XCTAssertEqual(vm.timerProgress, 0.0, accuracy: 1e-6)
        let t = vm.timerTimeTextOnlyForStatus
        XCTAssertEqual(t.count, 8) // HH:MM:SS
    }
    
    func test_timer_duringPeriod() {
        let udm = MVM_UserDefaultsMock()
        let nowHour = Calendar.current.component(.hour, from: Date())
        udm.startHour = nowHour
        udm.endHour = (nowHour + 1) % 24
        registerDependencies(udm: udm)
        
        let store = PostStore()
        let vm = MainViewModel(store: store)
        vm.currentTime = Date()
        
        XCTAssertEqual(vm.timerLabel, "До конца")
        XCTAssertGreaterThanOrEqual(vm.timerProgress, 0.0)
        XCTAssertLessThanOrEqual(vm.timerProgress, 1.0)
        let t = vm.timerTimeTextOnlyForStatus
        XCTAssertEqual(t.count, 8)
    }
    
    func test_timer_afterEnd() {
        let udm = MVM_UserDefaultsMock()
        let nowHour = Calendar.current.component(.hour, from: Date())
        udm.startHour = ((nowHour - 2) + 24) % 24
        udm.endHour = ((nowHour - 1) + 24) % 24
        registerDependencies(udm: udm)
        
        let store = PostStore()
        let vm = MainViewModel(store: store)
        vm.currentTime = Date()
        
        XCTAssertEqual(vm.timerLabel, "До старта")
        XCTAssertEqual(vm.timerProgress, 0.0, accuracy: 1e-6)
        let t = vm.timerTimeTextOnlyForStatus
        XCTAssertEqual(t.count, 8)
    }
}
