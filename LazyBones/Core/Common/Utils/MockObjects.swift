import Foundation

// MARK: - Mock Use Cases

class MockGetReportsUseCase: GetReportsUseCaseProtocol {
    var mockResult: Result<[DomainPost], GetReportsError> = .success([])
    
    func execute(input: GetReportsInput) async throws -> [DomainPost] {
        switch mockResult {
        case .success(let reports):
            return reports
        case .failure(let error):
            throw error
        }
    }
}

class MockDeleteReportUseCase: DeleteReportUseCaseProtocol {
    var mockResult: Result<Void, DeleteReportError> = .success(())
    
    func execute(input: DeleteReportInput) async throws -> Void {
        switch mockResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Services

class MockTelegramIntegrationService: TelegramIntegrationServiceProtocol {
    var externalPosts: [Post] = []
    var telegramToken: String?
    var telegramChatId: String?
    var telegramBotId: String?
    var lastUpdateId: Int?
    
    var fetchExternalPostsResult: Bool = true
    var deleteAllBotMessagesResult: Bool = true
    var fetchExternalPostsCalled: Bool = false
    var deleteAllBotMessagesCalled: Bool = false
    
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        self.telegramToken = token
        self.telegramChatId = chatId
        self.telegramBotId = botId
    }
    
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        return (token: telegramToken, chatId: telegramChatId, botId: telegramBotId)
    }
    
    func saveLastUpdateId(_ updateId: Int) {
        self.lastUpdateId = updateId
    }
    
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        fetchExternalPostsCalled = true
        completion(fetchExternalPostsResult)
    }
    
    func saveExternalPosts() {
        // Mock implementation
    }
    
    func loadExternalPosts() {
        // Mock implementation
    }
    
    func deleteBotMessages(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        deleteAllBotMessagesCalled = true
        completion(deleteAllBotMessagesResult)
    }
    
    func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? {
        // Mock implementation - return a sample post
        return Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Sample good item"],
            badItems: ["Sample bad item"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
    }
    
    func getAllPosts() -> [Post] {
        return externalPosts
    }
    
    func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String {
        return "Mock formatted report for \(deviceName)"
    }
    
    func refreshTelegramService() {
        // Mock implementation
    }
    
    func resetLastUpdateId() {
        self.lastUpdateId = 0
    }
} 