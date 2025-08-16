import XCTest
@testable import LazyBones

@MainActor
class AutoSendIntegrationTests: XCTestCase {
    
    var dependencyContainer: DependencyContainer!
    var autoSendService: AutoSendService!
    var postTelegramService: PostTelegramService!
    fileprivate var telegramService: MockTelegramService!
    fileprivate var userDefaultsManager: MockUserDefaultsManager!
    
    override func setUp() {
        super.setUp()
        
        // Создаем моки
        telegramService = MockTelegramService()
        userDefaultsManager = MockUserDefaultsManager()
        
        // Настраиваем DI контейнер
        dependencyContainer = DependencyContainer.shared
        dependencyContainer.clear()
        dependencyContainer.registerCoreServices()
        
        // Регистрируем моки
        dependencyContainer.register(TelegramServiceProtocol.self, instance: self.telegramService)
        
        dependencyContainer.register(UserDefaultsManagerProtocol.self, instance: self.userDefaultsManager)
        
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

private final class MockTelegramService: TelegramServiceProtocol {
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
    
    // Complete protocol methods
    func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws {
        if !shouldSucceed { throw NSError(domain: "TelegramError", code: 500) }
    }
    func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws {
        if !shouldSucceed { throw NSError(domain: "TelegramError", code: 500) }
    }
    func getMe() async throws -> TelegramUser { TelegramUser(id: 0, isBot: true, firstName: "Bot", lastName: nil, username: "mockbot") }
    func downloadFile(_ fileId: String) async throws -> Data { Data() }
}

// Local mock for UserDefaultsManagerProtocol
private final class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var stringValues: [String: String] = [:]
    var boolValues: [String: Bool] = [:]
    var intValues: [String: Int] = [:]
    var dataValues: [String: Data] = [:]
    var anyValues: [String: Any] = [:]

    func set<T>(_ value: T, forKey key: String) {
        if let v = value as? String { stringValues[key] = v }
        else if let v = value as? Bool { boolValues[key] = v }
        else if let v = value as? Int { intValues[key] = v }
        else if let v = value as? Data { dataValues[key] = v }
        anyValues[key] = value
    }
    func get<T>(_ type: T.Type, forKey key: String) -> T? { anyValues[key] as? T }
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { (anyValues[key] as? T) ?? defaultValue }
    func remove(forKey key: String) { stringValues.removeValue(forKey: key); boolValues.removeValue(forKey: key); intValues.removeValue(forKey: key); dataValues.removeValue(forKey: key); anyValues.removeValue(forKey: key) }
    func hasValue(forKey key: String) -> Bool { stringValues[key] != nil || boolValues[key] != nil || intValues[key] != nil || dataValues[key] != nil || anyValues[key] != nil }
    func bool(forKey key: String) -> Bool { boolValues[key] ?? false }
    func string(forKey key: String) -> String? { stringValues[key] }
    func integer(forKey key: String) -> Int { intValues[key] ?? 0 }
    func data(forKey key: String) -> Data? { dataValues[key] }
    func loadPosts() -> [Post] {
        if let data = dataValues["posts"], let arr = try? JSONDecoder().decode([Post].self, from: data) { return arr }
        return []
    }
    func savePosts(_ posts: [Post]) {
        if let data = try? JSONEncoder().encode(posts) { dataValues["posts"] = data }
    }
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        if let token = token { stringValues["telegramToken"] = token } else { remove(forKey: "telegramToken") }
        if let chatId = chatId { stringValues["telegramChatId"] = chatId } else { remove(forKey: "telegramChatId") }
        if let botId = botId { stringValues["telegramBotId"] = botId } else { remove(forKey: "telegramBotId") }
    }
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        (stringValues["telegramToken"], stringValues["telegramChatId"], stringValues["telegramBotId"])
    }
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