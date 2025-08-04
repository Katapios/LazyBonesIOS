import XCTest
@testable import LazyBones

@MainActor
class AutoSendIntegrationTests: XCTestCase {
    
    var dependencyContainer: DependencyContainer!
    var autoSendService: AutoSendService!
    var postTelegramService: PostTelegramService!
    var telegramService: MockTelegramService!
    var userDefaultsManager: MockUserDefaultsManager!
    
    override func setUp() {
        super.setUp()
        
        // Создаем моки
        telegramService = MockTelegramService()
        userDefaultsManager = MockUserDefaultsManager()
        
        // Настраиваем DI контейнер
        dependencyContainer = DependencyContainer()
        dependencyContainer.registerCoreServices()
        
        // Регистрируем моки
        dependencyContainer.register(TelegramServiceProtocol.self) { _ in
            return self.telegramService
        }
        
        dependencyContainer.register(UserDefaultsManagerProtocol.self) { _ in
            return self.userDefaultsManager
        }
        
        // Получаем сервисы
        postTelegramService = PostTelegramService(
            telegramService: telegramService,
            userDefaultsManager: userDefaultsManager
        )
        
        autoSendService = AutoSendService(
            userDefaultsManager: userDefaultsManager,
            postTelegramService: postTelegramService
        )
    }
    
    override func tearDown() {
        dependencyContainer = nil
        autoSendService = nil
        postTelegramService = nil
        telegramService = nil
        userDefaultsManager = nil
        super.tearDown()
    }
    
    // MARK: - Full Auto Send Flow Tests
    
    func testCompleteAutoSendFlow_RegularReport() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Создаем тестовый отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил 8 часов", "Сделал фичу"],
            badItems: ["Не гулял", "Пропустил спорт"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        // Сохраняем отчет
        let encodedData = try! JSONEncoder().encode([testPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        XCTAssertNotNil(telegramService.lastSentText)
        
        // Проверяем, что текст содержит данные отчета
        let sentText = telegramService.lastSentText ?? ""
        XCTAssertTrue(sentText.contains("Кодил 8 часов"))
        XCTAssertTrue(sentText.contains("Сделал фичу"))
        XCTAssertTrue(sentText.contains("Не гулял"))
        XCTAssertTrue(sentText.contains("Пропустил спорт"))
    }
    
    func testCompleteAutoSendFlow_CustomReport() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Создаем тестовый кастомный отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Изучить SwiftUI", "Сделать тесты"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true, false]
        )
        
        // Сохраняем отчет
        let encodedData = try! JSONEncoder().encode([testPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        XCTAssertNotNil(telegramService.lastSentText)
        
        // Проверяем, что текст содержит данные отчета
        let sentText = telegramService.lastSentText ?? ""
        XCTAssertTrue(sentText.contains("Изучить SwiftUI"))
        XCTAssertTrue(sentText.contains("Сделать тесты"))
        XCTAssertTrue(sentText.contains("✅")) // Выполнено
        XCTAssertTrue(sentText.contains("❌")) // Не выполнено
    }
    
    func testCompleteAutoSendFlow_BothReportTypes() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Создаем оба типа отчетов
        let regularPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил"],
            badItems: ["Не гулял"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        let customPost = Post(
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
        
        // Сохраняем отчеты
        let encodedData = try! JSONEncoder().encode([regularPost, customPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        XCTAssertNotNil(telegramService.lastSentText)
        
        // Проверяем, что текст содержит данные обоих отчетов
        let sentText = telegramService.lastSentText ?? ""
        XCTAssertTrue(sentText.contains("Кодил"))
        XCTAssertTrue(sentText.contains("Не гулял"))
        XCTAssertTrue(sentText.contains("План 1"))
        XCTAssertTrue(sentText.contains("План 2"))
    }
    
    func testCompleteAutoSendFlow_NoReports() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Нет отчетов
        userDefaultsManager.dataValues = [:]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        XCTAssertNotNil(telegramService.lastSentText)
        
        // Проверяем, что отправлено сообщение о том, что отчетов нет
        let sentText = telegramService.lastSentText ?? ""
        XCTAssertTrue(sentText.contains("не найдено ни одного отчета"))
    }
    
    func testCompleteAutoSendFlow_AlreadySentReports() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
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
        
        // Сохраняем отчеты
        let encodedData = try! JSONEncoder().encode([regularPost, customPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        // Не должно быть отправлено сообщений, так как отчеты уже отправлены
        XCTAssertFalse(telegramService.sendMessageCalled)
    }
    
    func testCompleteAutoSendFlow_TelegramError() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = false // Симулируем ошибку
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Создаем тестовый отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил"],
            badItems: ["Не гулял"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        // Сохраняем отчет
        let encodedData = try! JSONEncoder().encode([testPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        // Отчет не должен быть помечен как отправленный при ошибке
        // Это проверяется в PostTelegramService
    }
    
    // MARK: - Background Task Integration Tests
    
    func testBackgroundTaskAutoSend() async {
        // Given
        autoSendService.autoSendEnabled = true
        telegramService.shouldSucceed = true
        userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
        
        // Создаем тестовый отчет
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил"],
            badItems: ["Не гулял"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        // Сохраняем отчет
        let encodedData = try! JSONEncoder().encode([testPost])
        userDefaultsManager.dataValues = ["posts": encodedData]
        
        // When - симулируем вызов из background task
        autoSendService.performAutoSendReport()
        
        // Then
        // Ждем немного для асинхронных операций
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        XCTAssertTrue(telegramService.sendMessageCalled)
        XCTAssertNotNil(telegramService.lastSentText)
    }
}

// MARK: - Enhanced Mock Classes

class MockTelegramService: TelegramServiceProtocol {
    var shouldSucceed = true
    var sendMessageCalled = false
    var lastSentText: String?
    var lastChatId: String?
    
    func sendMessage(_ text: String, to chatId: String) async throws {
        sendMessageCalled = true
        lastSentText = text
        lastChatId = chatId
        
        if !shouldSucceed {
            throw NSError(domain: "TelegramError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
    }
    
    func getUpdates(offset: Int?) async throws -> [TelegramUpdate] {
        return []
    }
} 