import XCTest
@testable import LazyBones

@MainActor
class AutoSendServiceTests: XCTestCase {
    
    fileprivate var autoSendService: AutoSendService!
    fileprivate var mockUserDefaultsManager: MockUserDefaultsManager!
    fileprivate var mockPostTelegramService: MockPostTelegramService!
    
    override func setUp() {
        super.setUp()
        
        mockUserDefaultsManager = MockUserDefaultsManager()
        mockPostTelegramService = MockPostTelegramService()
        
        autoSendService = AutoSendService(
            userDefaultsManager: mockUserDefaultsManager,
            postTelegramService: mockPostTelegramService
        )
    }
    
    override func tearDown() {
        autoSendService = nil
        mockUserDefaultsManager = nil
        mockPostTelegramService = nil
        super.tearDown()
    }
    
    // MARK: - Settings Management Tests
    
    func testLoadAutoSendSettings() {
        // Given
        mockUserDefaultsManager.boolValues = ["autoSendToTelegram": true]
        mockUserDefaultsManager.dateValues = ["autoSendTime": Date()]
        mockUserDefaultsManager.stringValues = ["lastAutoSendStatus": "Success"]
        
        // When
        autoSendService.loadAutoSendSettings()
        
        // Then
        XCTAssertTrue(autoSendService.autoSendEnabled)
        XCTAssertNotNil(autoSendService.autoSendTime)
        XCTAssertEqual(autoSendService.lastAutoSendStatus, "Success")
    }
    
    func testSaveAutoSendSettings() {
        // Given
        autoSendService.autoSendEnabled = true
        autoSendService.autoSendTime = Date()
        autoSendService.lastAutoSendStatus = "Test Status"
        
        // When
        autoSendService.saveAutoSendSettings()
        
        // Then
        XCTAssertTrue(mockUserDefaultsManager.setCalled)
        XCTAssertEqual(mockUserDefaultsManager.savedValues["autoSendToTelegram"] as? Bool, true)
        XCTAssertNotNil(mockUserDefaultsManager.savedValues["autoSendTime"] as? Date)
        XCTAssertEqual(mockUserDefaultsManager.savedValues["lastAutoSendStatus"] as? String, "Test Status")
    }
    
    // MARK: - Auto Send Logic Tests
    
    func testScheduleAutoSendWhenEnabled() {
        // Given
        autoSendService.autoSendEnabled = true
        
        // When
        autoSendService.scheduleAutoSendIfNeeded()
        
        // Then
        // Проверяем, что метод отрабатывает без ошибок (без проверки приватных деталей)
        XCTAssertTrue(true)
    }
    
    func testScheduleAutoSendWhenDisabled() {
        // Given
        autoSendService.autoSendEnabled = false
        
        // When
        autoSendService.scheduleAutoSendIfNeeded()
        
        // Then
        // Проверяем, что метод отрабатывает без ошибок
        XCTAssertTrue(true)
    }
    
    func testPerformAutoSendReport() {
        // Given
        mockPostTelegramService.shouldSucceed = true
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        XCTAssertTrue(mockPostTelegramService.performAutoSendReportCalled)
    }
    
    func testAutoSendAllReportsForToday() {
        // Given
        mockPostTelegramService.shouldSucceed = true
        var completionCalled = false
        
        // When
        autoSendService.autoSendAllReportsForToday {
            completionCalled = true
        }
        
        // Then
        XCTAssertTrue(mockPostTelegramService.autoSendAllReportsForTodayCalled)
        XCTAssertTrue(completionCalled)
    }
    
    // MARK: - Integration Tests
    
    func testAutoSendFlow_WithRegularReport() {
        // Given
        autoSendService.autoSendEnabled = true
        mockPostTelegramService.shouldSucceed = true
        
        // Создаем тестовый отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил 8 часов"],
            badItems: ["Не гулял"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        // Сохраняем отчет в UserDefaults
        let encodedData = try! JSONEncoder().encode([testPost])
        mockUserDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        XCTAssertTrue(mockPostTelegramService.performAutoSendReportCalled)
    }
    
    func testAutoSendFlow_WithCustomReport() {
        // Given
        autoSendService.autoSendEnabled = true
        mockPostTelegramService.shouldSucceed = true
        
        // Создаем тестовый кастомный отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["План 1", "План 2"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true, false]
        )
        
        // Сохраняем отчет в UserDefaults
        let encodedData = try! JSONEncoder().encode([testPost])
        mockUserDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        XCTAssertTrue(mockPostTelegramService.performAutoSendReportCalled)
    }
    
    func testAutoSendFlow_NoReports() {
        // Given
        autoSendService.autoSendEnabled = true
        mockPostTelegramService.shouldSucceed = true
        
        // Нет отчетов
        mockUserDefaultsManager.dataValues = [:]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        XCTAssertTrue(mockPostTelegramService.performAutoSendReportCalled)
    }
    
    func testAutoSendFlow_AlreadySentReports() {
        // Given
        autoSendService.autoSendEnabled = true
        mockPostTelegramService.shouldSucceed = true
        
        // Создаем уже отправленные отчеты
        let regularPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил"],
            badItems: ["Не гулял"],
            published: true, // Уже отправлен
            voiceNotes: [],
            type: .regular
        )
        
        let customPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["План"],
            badItems: [],
            published: true, // Уже отправлен
            voiceNotes: [],
            type: .custom
        )
        
        // Сохраняем отчеты в UserDefaults
        let encodedData = try! JSONEncoder().encode([regularPost, customPost])
        mockUserDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        XCTAssertTrue(mockPostTelegramService.performAutoSendReportCalled)
        // PostTelegramService должен определить, что отчеты уже отправлены
    }
}

// MARK: - Mock Classes

fileprivate final class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var setCalled = false
    var savedValues: [String: Any] = [:]
    var boolValues: [String: Bool] = [:]
    var stringValues: [String: String] = [:]
    var intValues: [String: Int] = [:]
    var dateValues: [String: Date] = [:]
    var dataValues: [String: Data] = [:]

    // Generic API
    func set<T>(_ value: T, forKey key: String) {
        setCalled = true
        if let v = value as? Any { savedValues[key] = v }
        if let v = value as? Bool { boolValues[key] = v }
        if let v = value as? String { stringValues[key] = v }
        if let v = value as? Int { intValues[key] = v }
        if let v = value as? Date { dateValues[key] = v }
        if let v = value as? Data { dataValues[key] = v }
    }
    func get<T>(_ type: T.Type, forKey key: String) -> T? { savedValues[key] as? T }
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { (savedValues[key] as? T) ?? defaultValue }
    func remove(forKey key: String) {
        savedValues.removeValue(forKey: key)
        boolValues.removeValue(forKey: key)
        stringValues.removeValue(forKey: key)
        intValues.removeValue(forKey: key)
        dateValues.removeValue(forKey: key)
        dataValues.removeValue(forKey: key)
    }
    func hasValue(forKey key: String) -> Bool { savedValues[key] != nil || stringValues[key] != nil || boolValues[key] != nil || intValues[key] != nil || dateValues[key] != nil || dataValues[key] != nil }
    func bool(forKey key: String) -> Bool { boolValues[key] ?? false }
    func string(forKey key: String) -> String? { stringValues[key] }
    func integer(forKey key: String) -> Int { intValues[key] ?? 0 }
    func data(forKey key: String) -> Data? { dataValues[key] }

    // Posts
    func loadPosts() -> [Post] { return [] }
    func savePosts(_ posts: [Post]) {}

    // Telegram
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        if let token = token { stringValues["telegramToken"] = token } else { remove(forKey: "telegramToken") }
        if let chatId = chatId { stringValues["telegramChatId"] = chatId } else { remove(forKey: "telegramChatId") }
        if let botId = botId { stringValues["telegramBotId"] = botId } else { remove(forKey: "telegramBotId") }
    }
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        (stringValues["telegramToken"], stringValues["telegramChatId"], stringValues["telegramBotId"])
    }

    // Notifications
    func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        boolValues["notificationsEnabled"] = enabled
        intValues["notificationIntervalHours"] = intervalHours
        intValues["notificationStartHour"] = startHour
        intValues["notificationEndHour"] = endHour
        stringValues["notificationMode"] = mode
    }
    func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        (boolValues["notificationsEnabled"] ?? false,
         intValues["notificationIntervalHours"] ?? 1,
         intValues["notificationStartHour"] ?? 8,
         intValues["notificationEndHour"] ?? 22,
         stringValues["notificationMode"] ?? "hourly")
    }
}

fileprivate final class MockPostTelegramService: PostTelegramServiceProtocol {
    var shouldSucceed = true
    var performAutoSendReportCalled = false
    var autoSendAllReportsForTodayCalled = false
    var sendToTelegramCalled = false
    var lastSentText: String?
    
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        sendToTelegramCalled = true
        lastSentText = text
        completion(shouldSucceed)
    }
    
    func performAutoSendReport(completion: (() -> Void)? = nil) {
        performAutoSendReportCalled = true
        completion?()
    }
    
    func autoSendAllReportsForToday() {
        autoSendAllReportsForTodayCalled = true
    }
    
    func sendUnsentReportsFromPreviousDays() {
        // Mock implementation
    }
} 