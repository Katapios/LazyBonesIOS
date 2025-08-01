import XCTest
@testable import LazyBones

class NotificationManagerServiceTests: XCTestCase {
    
    var notificationManagerService: NotificationManagerService!
    var mockUserDefaultsManager: MockUserDefaultsManager!
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
        return UNNotificationSettings()
    }
    
    func debugNotificationStatus() async {
        // Mock implementation
    }
} 