import XCTest
@testable import LazyBones

class TelegramIntegrationServiceTests: XCTestCase {
    
    fileprivate var telegramIntegrationService: TelegramIntegrationService!
    fileprivate var mockUserDefaultsManager: MockUserDefaultsManager!
    fileprivate var mockTelegramService: MockTelegramService!

    
    override func setUp() {
        super.setUp()
        
        mockUserDefaultsManager = MockUserDefaultsManager()
        mockTelegramService = MockTelegramService()

        
        telegramIntegrationService = TelegramIntegrationService(
            userDefaultsManager: mockUserDefaultsManager,
            telegramService: mockTelegramService
        )
    }
    
    override func tearDown() {
        telegramIntegrationService = nil
        mockUserDefaultsManager = nil
        mockTelegramService = nil

        super.tearDown()
    }
    
    // MARK: - Settings Management Tests
    
    func testSaveTelegramSettings() {
        let token = "test_token"
        let chatId = "test_chat_id"
        let botId = "test_bot_id"
        
        telegramIntegrationService.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        
        XCTAssertEqual(telegramIntegrationService.telegramToken, token)
        XCTAssertEqual(telegramIntegrationService.telegramChatId, chatId)
        XCTAssertEqual(telegramIntegrationService.telegramBotId, botId)
        XCTAssertTrue(mockUserDefaultsManager.setCalled)
    }
    
    func testLoadTelegramSettings() {
        mockUserDefaultsManager.stringValues = [
            "telegramToken": "test_token",
            "telegramChatId": "test_chat_id",
            "telegramBotId": "test_bot_id"
        ]
        mockUserDefaultsManager.integerValues = ["lastUpdateId": 123]
        
        let settings = telegramIntegrationService.loadTelegramSettings()
        
        XCTAssertEqual(settings.token, "test_token")
        XCTAssertEqual(settings.chatId, "test_chat_id")
        XCTAssertEqual(settings.botId, "test_bot_id")
        XCTAssertEqual(telegramIntegrationService.lastUpdateId, 123)
    }
    
    func testSaveLastUpdateId() {
        let updateId = 456
        
        telegramIntegrationService.saveLastUpdateId(updateId)
        
        XCTAssertEqual(telegramIntegrationService.lastUpdateId, updateId)
        XCTAssertTrue(mockUserDefaultsManager.setCalled)
    }
    
    // MARK: - External Posts Management Tests
    
    func testLoadExternalPosts() {
        let testPosts = [
            Post(
                id: UUID(),
                date: Date(),
                goodItems: ["Test"],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external,
                isExternal: true
            )
        ]
        
        let encodedData = try! JSONEncoder().encode(testPosts)
        mockUserDefaultsManager.dataValues = ["externalPosts": encodedData]
        
        telegramIntegrationService.loadExternalPosts()
        
        XCTAssertEqual(telegramIntegrationService.externalPosts.count, 1)
        XCTAssertEqual(telegramIntegrationService.externalPosts.first?.type, .external)
    }
    
    func testLoadExternalPostsWithNoData() {
        telegramIntegrationService.loadExternalPosts()
        
        XCTAssertEqual(telegramIntegrationService.externalPosts.count, 0)
    }
    
    func testSaveExternalPosts() {
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Test"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .external,
            isExternal: true
        )
        
        telegramIntegrationService.externalPosts = [testPost]
        telegramIntegrationService.saveExternalPosts()
        
        XCTAssertTrue(mockUserDefaultsManager.setCalled)
    }
    
    // MARK: - Message Conversion Tests
    
    func testConvertTextMessageToPost() {
        let messageDict: [String: Any] = [
            "message_id": 123,
            "date": Int(Date().timeIntervalSince1970),
            "text": "Test message",
            "from": [
                "id": 456,
                "is_bot": false,
                "first_name": "Test",
                "last_name": "User",
                "username": "testuser"
            ]
        ]
        let message = try! decodeTelegramMessage(from: messageDict)
        
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Test message")
        XCTAssertEqual(post?.externalMessageId, 123)
        XCTAssertEqual(post?.authorId, 456)
    }
    
    func testConvertVoiceMessageToPost() {
        let messageDict: [String: Any] = [
            "message_id": 123,
            "date": Int(Date().timeIntervalSince1970),
            "caption": "Voice caption",
            "voice": [
                "file_id": "voice_file_id",
                "file_unique_id": "voice_unique_id",
                "duration": 30,
                "mime_type": NSNull(),
                "file_size": NSNull()
            ],
            "from": [
                "id": 456,
                "is_bot": false,
                "first_name": "Test",
                "last_name": "User",
                "username": "testuser"
            ]
        ]
        let message = try! decodeTelegramMessage(from: messageDict)
        
        telegramIntegrationService.telegramToken = "test_token"
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Voice caption")
        XCTAssertNotNil(post?.externalVoiceNoteURLs)
    }
    
    func testConvertAudioMessageToPost() {
        let messageDict: [String: Any] = [
            "message_id": 123,
            "date": Int(Date().timeIntervalSince1970),
            "caption": "Audio caption",
            "audio": [
                "file_id": "audio_file_id",
                "file_unique_id": "audio_unique_id",
                "duration": 60,
                "performer": NSNull(),
                "title": "Test Audio",
                "mime_type": NSNull(),
                "file_size": NSNull()
            ],
            "from": [
                "id": 456,
                "is_bot": false,
                "first_name": "Test",
                "last_name": "User",
                "username": "testuser"
            ]
        ]
        let message = try! decodeTelegramMessage(from: messageDict)
        
        telegramIntegrationService.telegramToken = "test_token"
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Audio caption")
        XCTAssertNotNil(post?.externalVoiceNoteURLs)
    }
    
    func testConvertDocumentMessageToPost() {
        let messageDict: [String: Any] = [
            "message_id": 123,
            "date": Int(Date().timeIntervalSince1970),
            "document": [
                "file_id": "doc_file_id",
                "file_unique_id": "doc_unique_id",
                "file_name": "test.pdf",
                "mime_type": NSNull(),
                "file_size": NSNull()
            ],
            "from": [
                "id": 456,
                "is_bot": false,
                "first_name": "Test",
                "last_name": "User",
                "username": "testuser"
            ]
        ]
        let message = try! decodeTelegramMessage(from: messageDict)
        
        telegramIntegrationService.telegramToken = "test_token"
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "test.pdf")
        XCTAssertNotNil(post?.externalVoiceNoteURLs)
    }
    
    // MARK: - Combined Posts Tests
    
    func testGetAllPosts() {
        let externalPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["External"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .external,
            isExternal: true
        )
        
        telegramIntegrationService.externalPosts = [externalPost]
        
        let allPosts = telegramIntegrationService.getAllPosts()
        
        XCTAssertEqual(allPosts.count, 1)
        XCTAssertTrue(allPosts.contains { $0.type == .external })
    }
}

// MARK: - Mock Classes

// MARK: - Helpers
private func decodeTelegramMessage(from dict: [String: Any]) throws -> TelegramMessage {
    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
    let decoder = JSONDecoder()
    return try decoder.decode(TelegramMessage.self, from: data)
}

private final class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var setCalled = false
    var stringValues: [String: String] = [:]
    var integerValues: [String: Int] = [:]
    var dataValues: [String: Data] = [:]
    var boolValues: [String: Bool] = [:]
    
    func set(_ value: Any?, forKey key: String) {
        setCalled = true
    }
    
    func string(forKey key: String) -> String? {
        return stringValues[key]
    }
    
    func integer(forKey key: String) -> Int {
        return integerValues[key] ?? 0
    }
    
    func data(forKey key: String) -> Data? {
        return dataValues[key]
    }
    
    func bool(forKey key: String) -> Bool {
        return boolValues[key] ?? false
    }
    
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        return (stringValues["telegramToken"], stringValues["telegramChatId"], stringValues["telegramBotId"])
    }

    // MARK: - Required protocol methods (stubs)
    func set<T>(_ value: T, forKey key: String) { setCalled = true }
    func get<T>(_ type: T.Type, forKey key: String) -> T? { return nil }
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { return defaultValue }
    func remove(forKey key: String) { stringValues.removeValue(forKey: key); integerValues.removeValue(forKey: key); dataValues.removeValue(forKey: key) }
    func hasValue(forKey key: String) -> Bool { stringValues[key] != nil || integerValues[key] != nil || dataValues[key] != nil }
    func loadPosts() -> [Post] { return [] }
    func savePosts(_ posts: [Post]) {}
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        stringValues["telegramToken"] = token
        stringValues["telegramChatId"] = chatId
        stringValues["telegramBotId"] = botId
        setCalled = true
    }
    func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {}
    func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) { (false, 1, 8, 22, "hourly") }
}

private final class MockTelegramService: TelegramServiceProtocol {
    func sendMessage(_ text: String, to chatId: String) async throws {
        // Mock implementation
    }
    
    func getUpdates(offset: Int?) async throws -> [TelegramUpdate] {
        return []
    }

    // MARK: - Required protocol methods (stubs)
    func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws {}
    func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws {}
    func getMe() async throws -> TelegramUser { return TelegramUser(id: 0, isBot: true, firstName: "bot", lastName: nil, username: nil) }
    func downloadFile(_ fileId: String) async throws -> Data { return Data() }
}

 