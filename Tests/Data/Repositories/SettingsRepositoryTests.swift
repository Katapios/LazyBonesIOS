import XCTest
@testable import LazyBones

final class SettingsRepositoryTests: XCTestCase {
    // Minimal mock for UserDefaultsManagerProtocol
    final class MockUserDefaultsManager: UserDefaultsManagerProtocol {
        var setCalls: [(Any, String)] = []
        var removedKeys: [String] = []
        var storedStrings: [String: String] = [:]
        var storedBools: [String: Bool] = [:]
        var storedInts: [String: Int] = [:]
        var storedData: [String: Data] = [:]
        var storedAny: [String: Any] = [:]
        var telegramToken: String?
        var telegramChatId: String?
        var telegramBotId: String?

        func set<T>(_ value: T, forKey key: String) {
            setCalls.append((value as Any, key))
            if let v = value as? String { storedStrings[key] = v }
            else if let v = value as? Bool { storedBools[key] = v }
            else if let v = value as? Int { storedInts[key] = v }
            else if let v = value as? Data { storedData[key] = v }
            else { storedAny[key] = value as Any }
        }
        func get<T>(_ type: T.Type, forKey key: String) -> T? { storedAny[key] as? T }
        func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { (storedAny[key] as? T) ?? defaultValue }
        func remove(forKey key: String) { removedKeys.append(key); storedStrings.removeValue(forKey: key); storedAny.removeValue(forKey: key) }
        func hasValue(forKey key: String) -> Bool { storedAny[key] != nil || storedStrings[key] != nil }
        func bool(forKey key: String) -> Bool { storedBools[key] ?? false }
        func string(forKey key: String) -> String? { storedStrings[key] }
        func integer(forKey key: String) -> Int { storedInts[key] ?? 0 }
        func data(forKey key: String) -> Data? { storedData[key] }
        func loadPosts() -> [Post] { return [] }
        func savePosts(_ posts: [Post]) {}
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
            if let token = token { storedStrings["telegramToken"] = token } else { remove(forKey: "telegramToken") }
            if let chatId = chatId { storedStrings["telegramChatId"] = chatId } else { remove(forKey: "telegramChatId") }
            if let botId = botId { storedStrings["telegramBotId"] = botId } else { remove(forKey: "telegramBotId") }
        }
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
            (storedStrings["telegramToken"], storedStrings["telegramChatId"], storedStrings["telegramBotId"])
        }
    }

    func testSaveTelegramSettings_WithNilValues_DoesNotCrash_AndRemovesKeys() async throws {
        let mockUD = MockUserDefaultsManager()
        // Pre-fill some values
        mockUD.storedStrings["telegramToken"] = "oldToken"
        mockUD.storedStrings["telegramChatId"] = "oldChat"
        mockUD.storedStrings["telegramBotId"] = "oldBot"
        let repo = SettingsRepository(userDefaultsManager: mockUD)

        // Act: save nils
        try await repo.saveTelegramSettings(token: nil, chatId: nil, botId: nil)

        // Assert: keys were removed
        XCTAssertTrue(mockUD.removedKeys.contains("telegramToken"))
        XCTAssertTrue(mockUD.removedKeys.contains("telegramChatId"))
        XCTAssertTrue(mockUD.removedKeys.contains("telegramBotId"))
        XCTAssertNil(mockUD.storedStrings["telegramToken"]) 
        XCTAssertNil(mockUD.storedStrings["telegramChatId"]) 
        XCTAssertNil(mockUD.storedStrings["telegramBotId"]) 
    }

    func testLoadTelegramSettings_UsesManagerHelper() async throws {
        let mockUD = MockUserDefaultsManager()
        mockUD.storedStrings["telegramToken"] = "t"
        mockUD.storedStrings["telegramChatId"] = "c"
        mockUD.storedStrings["telegramBotId"] = "b"
        let repo = SettingsRepository(userDefaultsManager: mockUD)

        let result = try await repo.loadTelegramSettings()
        XCTAssertEqual(result.token, "t")
        XCTAssertEqual(result.chatId, "c")
        XCTAssertEqual(result.botId, "b")
    }
}
