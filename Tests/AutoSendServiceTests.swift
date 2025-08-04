import XCTest
@testable import LazyBones

@MainActor
class AutoSendServiceTests: XCTestCase {
    
    var autoSendService: AutoSendService!
    var mockUserDefaultsManager: MockUserDefaultsManager!
    var mockPostTelegramService: MockPostTelegramService!
    
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
        // В DEBUG режиме должен создаться timer
        #if DEBUG
        XCTAssertNotNil(autoSendService.autoSendTimer)
        #endif
    }
    
    func testScheduleAutoSendWhenDisabled() {
        // Given
        autoSendService.autoSendEnabled = false
        
        // When
        autoSendService.scheduleAutoSendIfNeeded()
        
        // Then
        // Timer не должен создаваться
        XCTAssertNil(autoSendService.autoSendTimer)
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

class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var setCalled = false
    var savedValues: [String: Any] = [:]
    var boolValues: [String: Bool] = [:]
    var stringValues: [String: String] = [:]
    var dateValues: [String: Date] = [:]
    var dataValues: [String: Data] = [:]
    
    func set(_ value: Any?, forKey key: String) {
        setCalled = true
        if let value = value {
            savedValues[key] = value
        }
    }
    
    func bool(forKey key: String) -> Bool {
        return boolValues[key] ?? false
    }
    
    func string(forKey key: String) -> String? {
        return stringValues[key]
    }
    
    func data(forKey key: String) -> Data? {
        return dataValues[key]
    }
    
    func object(forKey key: String) -> Any? {
        if let date = dateValues[key] {
            return date
        }
        return nil
    }
}

class MockPostTelegramService: PostTelegramServiceProtocol {
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