import XCTest
import UserNotifications
@testable import LazyBones

// Local mock to avoid name clashes in other test files
private final class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    private var bools: [String: Bool] = [:]
    private var strings: [String: String] = [:]
    private var ints: [String: Int] = [:]
    private var datas: [String: Data] = [:]
    private var anys: [String: Any] = [:]

    // Helpers used by tests
    func clear() {
        bools.removeAll(); strings.removeAll(); ints.removeAll(); datas.removeAll(); anys.removeAll()
    }

    // Protocol methods
    func set<T>(_ value: T, forKey key: String) {
        if let v = value as? Bool { bools[key] = v }
        else if let v = value as? String { strings[key] = v }
        else if let v = value as? Int { ints[key] = v }
        else if let v = value as? Data { datas[key] = v }
        anys[key] = value
    }
    func get<T>(_ type: T.Type, forKey key: String) -> T? { anys[key] as? T }
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { (anys[key] as? T) ?? defaultValue }
    func remove(forKey key: String) { bools.removeValue(forKey: key); strings.removeValue(forKey: key); ints.removeValue(forKey: key); datas.removeValue(forKey: key); anys.removeValue(forKey: key) }
    func hasValue(forKey key: String) -> Bool { anys[key] != nil || strings[key] != nil || bools[key] != nil || ints[key] != nil || datas[key] != nil }
    func bool(forKey key: String) -> Bool { bools[key] ?? false }
    func string(forKey key: String) -> String? { strings[key] }
    func integer(forKey key: String) -> Int { ints[key] ?? 0 }
    func data(forKey key: String) -> Data? { datas[key] }
    func loadPosts() -> [Post] { [] }
    func savePosts(_ posts: [Post]) {}
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        if let token = token { strings["telegramToken"] = token } else { remove(forKey: "telegramToken") }
        if let chatId = chatId { strings["telegramChatId"] = chatId } else { remove(forKey: "telegramChatId") }
        if let botId = botId { strings["telegramBotId"] = botId } else { remove(forKey: "telegramBotId") }
    }
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        (strings["telegramToken"], strings["telegramChatId"], strings["telegramBotId"])
    }
    func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        bools["notificationsEnabled"] = enabled
        ints["notificationIntervalHours"] = intervalHours
        ints["notificationStartHour"] = startHour
        ints["notificationEndHour"] = endHour
        strings["notificationMode"] = mode
    }
    func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        (bools["notificationsEnabled"] ?? false,
         ints["notificationIntervalHours"] ?? 1,
         ints["notificationStartHour"] ?? 8,
         ints["notificationEndHour"] ?? 22,
         strings["notificationMode"] ?? "hourly")
    }
}

class NotificationManagerServiceTests: XCTestCase {
    
    var notificationManagerService: NotificationManagerService!
    fileprivate var mockUserDefaultsManager: MockUserDefaultsManager!
    var mockNotificationService: MockNotificationService!
    
    override func setUp() {
        super.setUp()
        
        mockUserDefaultsManager = MockUserDefaultsManager()
        mockNotificationService = MockNotificationService()
        notificationManagerService = NotificationManagerService(
            userDefaultsManager: mockUserDefaultsManager,
            notificationService: mockNotificationService
        )
    }
    
    override func tearDown() {
        notificationManagerService = nil
        mockUserDefaultsManager = nil
        mockNotificationService = nil
        super.tearDown()
    }
    
    // MARK: - Settings Management Tests
    
    func testSaveNotificationSettings() {
        // Given
        notificationManagerService.notificationsEnabled = true
        notificationManagerService.notificationMode = .twice
        notificationManagerService.notificationIntervalHours = 3
        notificationManagerService.notificationStartHour = 9
        notificationManagerService.notificationEndHour = 21
        
        // When
        notificationManagerService.saveNotificationSettings()
        
        // Then
        XCTAssertTrue(mockUserDefaultsManager.bool(forKey: "notificationsEnabled"))
        XCTAssertEqual(mockUserDefaultsManager.string(forKey: "notificationMode"), "twice")
        XCTAssertEqual(mockUserDefaultsManager.integer(forKey: "notificationIntervalHours"), 3)
        XCTAssertEqual(mockUserDefaultsManager.integer(forKey: "notificationStartHour"), 9)
        XCTAssertEqual(mockUserDefaultsManager.integer(forKey: "notificationEndHour"), 21)
    }
    
    func testLoadNotificationSettings() {
        // Given
        mockUserDefaultsManager.set(true, forKey: "notificationsEnabled")
        mockUserDefaultsManager.set("twice", forKey: "notificationMode")
        mockUserDefaultsManager.set(4, forKey: "notificationIntervalHours")
        mockUserDefaultsManager.set(10, forKey: "notificationStartHour")
        mockUserDefaultsManager.set(20, forKey: "notificationEndHour")
        
        // When
        notificationManagerService.loadNotificationSettings()
        
        // Then
        XCTAssertTrue(notificationManagerService.notificationsEnabled)
        XCTAssertEqual(notificationManagerService.notificationMode, .twice)
        XCTAssertEqual(notificationManagerService.notificationIntervalHours, 4)
        XCTAssertEqual(notificationManagerService.notificationStartHour, 10)
        XCTAssertEqual(notificationManagerService.notificationEndHour, 20)
    }
    
    func testLoadNotificationSettingsWithDefaults() {
        // Given - no settings saved
        mockUserDefaultsManager.clear()
        
        // When
        notificationManagerService.loadNotificationSettings()
        
        // Then
        XCTAssertFalse(notificationManagerService.notificationsEnabled)
        XCTAssertEqual(notificationManagerService.notificationMode, .hourly)
        XCTAssertEqual(notificationManagerService.notificationIntervalHours, 1)
        XCTAssertEqual(notificationManagerService.notificationStartHour, 8)
        XCTAssertEqual(notificationManagerService.notificationEndHour, 22)
    }
    
    // MARK: - Notification Logic Tests
    
    func testScheduleNotificationsWhenDisabled() {
        // Given
        notificationManagerService.notificationsEnabled = false
        
        // When
        notificationManagerService.scheduleNotifications()
        
        // Then
        XCTAssertFalse(mockNotificationService.scheduleReportNotificationsCalled)
    }
    
    func testScheduleNotificationsWhenEnabled() {
        // Given
        notificationManagerService.notificationsEnabled = true
        notificationManagerService.notificationMode = .hourly
        notificationManagerService.notificationIntervalHours = 2
        notificationManagerService.notificationStartHour = 9
        notificationManagerService.notificationEndHour = 18
        
        // When
        notificationManagerService.scheduleNotifications()
        
        // Then
        XCTAssertTrue(mockNotificationService.scheduleReportNotificationsCalled)
        XCTAssertEqual(mockNotificationService.lastIntervalHours, 2)
        XCTAssertEqual(mockNotificationService.lastStartHour, 9)
        XCTAssertEqual(mockNotificationService.lastEndHour, 18)
        XCTAssertEqual(mockNotificationService.lastMode, "hourly")
    }
    
    func testCancelAllNotifications() {
        // When
        notificationManagerService.cancelAllNotifications()
        
        // Then
        XCTAssertTrue(mockNotificationService.cancelAllNotificationsCalled)
    }
    
    // MARK: - Helper Methods Tests
    
    func testNotificationScheduleForTodayWhenDisabled() {
        // Given
        notificationManagerService.notificationsEnabled = false
        
        // When
        let schedule = notificationManagerService.notificationScheduleForToday()
        
        // Then
        XCTAssertNil(schedule)
    }
    
    func testNotificationScheduleForTodayHourlyMode() {
        // Given
        notificationManagerService.notificationsEnabled = true
        notificationManagerService.notificationMode = .hourly
        notificationManagerService.notificationStartHour = 9
        notificationManagerService.notificationEndHour = 18
        
        // When
        let schedule = notificationManagerService.notificationScheduleForToday()
        
        // Then
        XCTAssertEqual(schedule, "Каждый час с 9:00 до 18:00")
    }
    
    func testNotificationScheduleForTodayTwiceMode() {
        // Given
        notificationManagerService.notificationsEnabled = true
        notificationManagerService.notificationMode = .twice
        notificationManagerService.notificationIntervalHours = 3
        notificationManagerService.notificationStartHour = 8
        notificationManagerService.notificationEndHour = 20
        
        // When
        let schedule = notificationManagerService.notificationScheduleForToday()
        
        // Then
        XCTAssertEqual(schedule, "Каждые 3 часа с 8:00 до 20:00")
    }
}

// MARK: - Mock Classes

class MockNotificationService: NotificationServiceProtocol {
    var scheduleReportNotificationsCalled = false
    var lastIntervalHours: Int = 0
    var lastStartHour: Int = 0
    var lastEndHour: Int = 0
    var lastMode: String = ""
    var cancelAllNotificationsCalled = false
    
    func requestPermission() async throws -> Bool {
        return true
    }
    
    func scheduleNotification(title: String, body: String, date: Date, identifier: String) async throws {
        // Mock implementation
    }
    
    func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws {
        // Mock implementation
    }
    
    func scheduleReportNotifications(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) async throws {
        scheduleReportNotificationsCalled = true
        lastIntervalHours = intervalHours
        lastStartHour = startHour
        lastEndHour = endHour
        lastMode = mode
    }
    
    func cancelNotification(identifier: String) async throws {
        // Mock implementation
    }
    
    func cancelAllNotifications() async throws {
        cancelAllNotificationsCalled = true
    }
    
    func getPendingNotifications() async throws -> [UNNotificationRequest] {
        return []
    }
    
    func getDeliveredNotifications() async throws -> [UNNotification] {
        return []
    }
    
    func checkNotificationPermission() async -> Bool {
        return true
    }
    
    func getNotificationSettings() async -> UNNotificationSettings {
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
    
    func debugNotificationStatus() async {
        // Mock implementation
    }
} 