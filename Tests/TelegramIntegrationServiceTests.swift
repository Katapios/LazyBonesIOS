import XCTest
@testable import LazyBones

class TelegramIntegrationServiceTests: XCTestCase {
    
    var telegramIntegrationService: TelegramIntegrationService!
    var mockUserDefaultsManager: MockUserDefaultsManager!
    var mockTelegramService: MockTelegramService!

    
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
        let message = TelegramMessage(
            messageId: 123,
            date: Int(Date().timeIntervalSince1970),
            text: "Test message",
            from: TelegramUser(id: 456, firstName: "Test", lastName: "User", username: "testuser")
        )
        
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Test message")
        XCTAssertEqual(post?.externalMessageId, 123)
        XCTAssertEqual(post?.authorId, 456)
    }
    
    func testConvertVoiceMessageToPost() {
        let voice = TelegramVoice(fileId: "voice_file_id", duration: 30)
        let message = TelegramMessage(
            messageId: 123,
            date: Int(Date().timeIntervalSince1970),
            voice: voice,
            caption: "Voice caption",
            from: TelegramUser(id: 456, firstName: "Test", lastName: "User", username: "testuser")
        )
        
        telegramIntegrationService.telegramToken = "test_token"
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Voice caption")
        XCTAssertNotNil(post?.externalVoiceNoteURLs)
    }
    
    func testConvertAudioMessageToPost() {
        let audio = TelegramAudio(fileId: "audio_file_id", duration: 60, title: "Test Audio")
        let message = TelegramMessage(
            messageId: 123,
            date: Int(Date().timeIntervalSince1970),
            audio: audio,
            caption: "Audio caption",
            from: TelegramUser(id: 456, firstName: "Test", lastName: "User", username: "testuser")
        )
        
        telegramIntegrationService.telegramToken = "test_token"
        let post = telegramIntegrationService.convertTelegramMessageToPost(message)
        
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.type, .external)
        XCTAssertEqual(post?.isExternal, true)
        XCTAssertEqual(post?.externalText, "Audio caption")
        XCTAssertNotNil(post?.externalVoiceNoteURLs)
    }
    
    func testConvertDocumentMessageToPost() {
        let document = TelegramDocument(fileId: "doc_file_id", fileName: "test.pdf")
        let message = TelegramMessage(
            messageId: 123,
            date: Int(Date().timeIntervalSince1970),
            document: document,
            from: TelegramUser(id: 456, firstName: "Test", lastName: "User", username: "testuser")
        )
        
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

class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var setCalled = false
    var stringValues: [String: String] = [:]
    var integerValues: [String: Int] = [:]
    var dataValues: [String: Data] = [:]
    
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
    
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        return (stringValues["telegramToken"], stringValues["telegramChatId"], stringValues["telegramBotId"])
    }
}

class MockTelegramService: TelegramServiceProtocol {
    func sendMessage(_ text: String, to chatId: String) async throws {
        // Mock implementation
    }
    
    func getUpdates(offset: Int?) async throws -> [TelegramUpdate] {
        return []
    }
}

 