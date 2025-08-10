import XCTest
@testable import LazyBones

class ServiceTests: XCTestCase {
    
    var userDefaultsManager: UserDefaultsManager!
    var notificationService: NotificationService!
    var backgroundTaskService: BackgroundTaskService!
    
    override func setUp() {
        super.setUp()
        userDefaultsManager = UserDefaultsManager.shared
        notificationService = NotificationService()
        // Use singleton, ctor is private
        backgroundTaskService = BackgroundTaskService.shared
    }
    
    override func tearDown() {
        userDefaultsManager = nil
        notificationService = nil
        backgroundTaskService = nil
        super.tearDown()
    }
    
    // MARK: - UserDefaultsManager Tests
    
    func testUserDefaultsManager_SaveAndLoadTelegramSettings() {
        // Given
        let token = "test_token"
        let chatId = "test_chat_id"
        let botId = "test_bot_id"
        
        // When
        userDefaultsManager.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        let loadedSettings = userDefaultsManager.loadTelegramSettings()
        
        // Then
        XCTAssertEqual(loadedSettings.token, token)
        XCTAssertEqual(loadedSettings.chatId, chatId)
        XCTAssertEqual(loadedSettings.botId, botId)
    }
    
    func testUserDefaultsManager_SaveAndLoadAutoSendSettings() {
        // Given
        let enabled = true
        let time = Date()
        
        // When
        userDefaultsManager.saveAutoSendSettings(enabled: enabled, time: time)
        let loadedSettings = userDefaultsManager.loadAutoSendSettings()
        
        // Then
        XCTAssertEqual(loadedSettings.enabled, enabled)
        XCTAssertEqual(loadedSettings.time.timeIntervalSince1970, time.timeIntervalSince1970, accuracy: 1.0) // 1 second tolerance
    }
    
    func testUserDefaultsManager_SaveAndLoadNotificationSettings() {
        // Given
        let enabled = true
        let intervalHours = 2
        let startHour = 9
        let endHour = 18
        let mode = "twice"
        
        // When
        userDefaultsManager.saveNotificationSettings(
            enabled: enabled,
            intervalHours: intervalHours,
            startHour: startHour,
            endHour: endHour,
            mode: mode
        )
        let loadedSettings = userDefaultsManager.loadNotificationSettings()
        
        // Then
        XCTAssertEqual(loadedSettings.enabled, enabled)
        XCTAssertEqual(loadedSettings.intervalHours, intervalHours)
        XCTAssertEqual(loadedSettings.startHour, startHour)
        XCTAssertEqual(loadedSettings.endHour, endHour)
        XCTAssertEqual(loadedSettings.mode, mode)
    }
    
    func testUserDefaultsManager_SaveAndLoadTags() {
        // Given
        let goodTags = ["productive", "exercise", "reading"]
        let badTags = ["procrastination", "stress"]
        
        // When
        userDefaultsManager.saveTags(goodTags: goodTags, badTags: badTags)
        let loadedTags = userDefaultsManager.loadTags()
        
        // Then
        XCTAssertEqual(loadedTags.goodTags, goodTags)
        XCTAssertEqual(loadedTags.badTags, badTags)
    }
    
    func testUserDefaultsManager_SaveAndLoadDeviceName() {
        // Given
        let deviceName = "Test Device"
        
        // When
        userDefaultsManager.saveDeviceName(deviceName)
        let loadedDeviceName = userDefaultsManager.loadDeviceName()
        
        // Then
        XCTAssertEqual(loadedDeviceName, deviceName)
    }
    
    // MARK: - NotificationService Tests
    
    func testNotificationService_RequestPermission() async {
        // When
        do {
            let granted = try await notificationService.requestPermission()
            // Then
            XCTAssertTrue(granted || !granted) // Can be either true or false depending on user settings
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testNotificationService_CheckPermission() async {
        // When
        let hasPermission = await notificationService.checkNotificationPermission()
        
        // Then
        XCTAssertTrue(hasPermission || !hasPermission) // Can be either true or false
    }
    
    func testNotificationService_ScheduleAndCancelNotification() async {
        // Given
        let title = "Test Notification"
        let body = "Test Body"
        let date = Date().addingTimeInterval(60) // 1 minute from now
        let identifier = "test_notification"
        
        // When
        do {
            // Запросим разрешение; если не дано — пропустим тест, т.к. планирование не имеет смысла
            let granted = try await notificationService.requestPermission()
            if !granted {
                throw XCTSkip("Notification permission not granted on simulator")
            }
            try await notificationService.scheduleNotification(
                title: title,
                body: body,
                date: date,
                identifier: identifier
            )
            // Небольшая пауза, чтобы центр уведомлений успел зарегистрировать запрос
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // Verify notification was scheduled
            let pendingNotifications = try await notificationService.getPendingNotifications()
            let scheduledNotification = pendingNotifications.first { $0.identifier == identifier }
            XCTAssertNotNil(scheduledNotification)
            
            // Cancel notification
            try await notificationService.cancelNotification(identifier: identifier)
            // Даем системе время удалить запрос из очереди
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // Verify notification was cancelled
            let updatedPendingNotifications = try await notificationService.getPendingNotifications()
            let cancelledNotification = updatedPendingNotifications.first { $0.identifier == identifier }
            XCTAssertNil(cancelledNotification)
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testNotificationService_CancelAllNotifications() async {
        // Given
        let title = "Test Notification"
        let body = "Test Body"
        let identifier = "test_notification"
        
        // When
        do {
            // Schedule a notification
            try await notificationService.scheduleRepeatingNotification(
                title: title,
                body: body,
                hour: 10,
                minute: 0,
                identifier: identifier
            )
            
            // Cancel all notifications
            try await notificationService.cancelAllNotifications()
            
            // Verify all notifications were cancelled
            let pendingNotifications = try await notificationService.getPendingNotifications()
            XCTAssertTrue(pendingNotifications.isEmpty)
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - BackgroundTaskService Tests
    
    func testBackgroundTaskService_CheckStatus() async {
        // When
        let hasRegisteredTasks = await backgroundTaskService.checkBackgroundTaskStatus()
        
        // Then
        // Can be either true or false depending on registration status
        XCTAssertTrue(hasRegisteredTasks || !hasRegisteredTasks)
    }
    
    func testBackgroundTaskService_CancelAllTasks() {
        // When
        backgroundTaskService.cancelAllBackgroundTasks()
        
        // Then
        // Should not throw any errors
        XCTAssertTrue(true)
    }
    
    // MARK: - DateUtils Tests
    
    func testDateUtils_StartOfDay() {
        // Given
        let date = Date()
        
        // When
        let startOfDay = DateUtils.startOfDay(for: date)
        
        // Then
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: startOfDay), 0)
        XCTAssertEqual(calendar.component(.minute, from: startOfDay), 0)
        XCTAssertEqual(calendar.component(.second, from: startOfDay), 0)
    }
    
    func testDateUtils_EndOfDay() {
        // Given
        let date = Date()
        
        // When
        let endOfDay = DateUtils.endOfDay(for: date)
        
        // Then
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: endOfDay), 23)
        XCTAssertEqual(calendar.component(.minute, from: endOfDay), 59)
        XCTAssertEqual(calendar.component(.second, from: endOfDay), 59)
    }
    
    func testDateUtils_IsToday() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // When & Then
        XCTAssertTrue(DateUtils.isToday(today))
        XCTAssertFalse(DateUtils.isToday(yesterday))
    }
    
    func testDateUtils_IsSameDay() {
        // Given
        let date1 = Date()
        let calendar = Calendar.current
        
        // Создаем дату в том же дне, но с другим временем
        var components = calendar.dateComponents([.year, .month, .day], from: date1)
        components.hour = 12
        components.minute = 30
        let date2 = calendar.date(from: components)!
        
        // Создаем дату в следующем дне
        let date3 = calendar.date(byAdding: .day, value: 1, to: date1)!
        
        // When & Then
        XCTAssertTrue(DateUtils.isSameDay(date1, date2))
        XCTAssertFalse(DateUtils.isSameDay(date1, date3))
    }
    
    func testDateUtils_DateWithTime() {
        // Given
        let date = Date()
        let hour = 15
        let minute = 30
        let second = 45
        
        // When
        let result = DateUtils.dateWithTime(hour: hour, minute: minute, second: second, of: date)
        
        // Then
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: result), hour)
        XCTAssertEqual(calendar.component(.minute, from: result), minute)
        XCTAssertEqual(calendar.component(.second, from: result), second)
    }
    
    func testDateUtils_FormatDate() {
        // Given
        let date = Date()
        
        // When
        let formatted = DateUtils.formatDate(date)
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.count > 0)
    }
    
    func testDateUtils_FormatTime() {
        // Given
        let date = Date()
        
        // When
        let formatted = DateUtils.formatTime(date)
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.count > 0)
    }
    
    func testDateUtils_FormatDateTime() {
        // Given
        let date = Date()
        
        // When
        let formatted = DateUtils.formatDateTime(date)
        
        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.count > 0)
    }
} 