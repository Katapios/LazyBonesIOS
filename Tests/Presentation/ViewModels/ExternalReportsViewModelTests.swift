import XCTest
@testable import LazyBones

@MainActor
class ExternalReportsViewModelTests: XCTestCase {
    var viewModel: ExternalReportsViewModel!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    var mockTelegramIntegrationService: MockTelegramIntegrationService!
    
    override func setUp() {
        super.setUp()
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockDeleteReportUseCase = MockDeleteReportUseCase()
        mockTelegramIntegrationService = MockTelegramIntegrationService()
        
        viewModel = ExternalReportsViewModel(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockGetReportsUseCase = nil
        mockDeleteReportUseCase = nil
        mockTelegramIntegrationService = nil
        super.tearDown()
    }
    
    // MARK: - Load Reports Tests
    
    func testLoadReports_Success() async {
        // Given
        let expectedReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Тест"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "test_user",
                authorFirstName: "Test",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Тестовый отчет",
                externalMessageId: 123,
                authorId: 456
            )
        ]
        mockGetReportsUseCase.mockResult = .success(expectedReports)
        mockTelegramIntegrationService.telegramToken = "test_token"
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reports.first?.type, .external)
        XCTAssertEqual(viewModel.state.reports.first?.authorUsername, "test_user")
        XCTAssertTrue(viewModel.state.telegramConnected)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testLoadReports_Error() async {
        // Given
        let expectedError = NSError(domain: "Test", code: 1, userInfo: nil)
        mockGetReportsUseCase.mockResult = .failure(.repositoryError(expectedError))
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.error as? NSError, expectedError)
    }
    
    // MARK: - Refresh From Telegram Tests
    
    func testRefreshFromTelegram_Success() async {
        // Given
        mockTelegramIntegrationService.fetchExternalPostsResult = true
        let expectedReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Обновленный"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "updated_user",
                authorFirstName: "Updated",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Обновленный отчет",
                externalMessageId: 789,
                authorId: 101
            )
        ]
        mockGetReportsUseCase.mockResult = .success(expectedReports)
        
        // When
        await viewModel.handle(.refreshFromTelegram)
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reports.first?.externalText, "Обновленный отчет")
        XCTAssertFalse(viewModel.state.isRefreshing)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testRefreshFromTelegram_Error() async {
        // Given
        mockTelegramIntegrationService.fetchExternalPostsResult = false
        
        // When
        await viewModel.handle(.refreshFromTelegram)
        
        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isRefreshing)
        XCTAssertNotNil(viewModel.state.error)
    }
    
    // MARK: - Clear History Tests
    
    func testClearHistory_Success() async {
        // Given
        mockTelegramIntegrationService.deleteAllBotMessagesResult = true
        viewModel.state.reports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Тест"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "test_user",
                authorFirstName: "Test",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Тестовый отчет",
                externalMessageId: 123,
                authorId: 456
            )
        ]
        
        // When
        await viewModel.handle(.clearHistory)
        
        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testClearHistory_Error() async {
        // Given
        mockTelegramIntegrationService.deleteAllBotMessagesResult = false
        viewModel.state.reports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Тест"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "test_user",
                authorFirstName: "Test",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Тестовый отчет",
                externalMessageId: 123,
                authorId: 456
            )
        ]
        
        // When
        await viewModel.handle(.clearHistory)
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1) // Не изменилось
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.error)
    }
    
    // MARK: - Selection Mode Tests
    
    func testToggleSelectionMode() async {
        // Given
        XCTAssertFalse(viewModel.state.isSelectionMode)
        
        // When
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertTrue(viewModel.state.isSelectionMode)
        
        // When - toggle back
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertFalse(viewModel.state.isSelectionMode)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
    }
    
    func testSelectReport() async {
        // Given
        let reportId = UUID()
        viewModel.state.reports = [
            DomainPost(
                id: reportId,
                date: Date(),
                goodItems: ["Тест"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "test_user",
                authorFirstName: "Test",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Тестовый отчет",
                externalMessageId: 123,
                authorId: 456
            )
        ]
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectReport(reportId))
        
        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(reportId))
        XCTAssertEqual(viewModel.state.selectedCount, 1)
        
        // When - deselect
        await viewModel.handle(.selectReport(reportId))
        
        // Then
        XCTAssertFalse(viewModel.state.selectedReportIDs.contains(reportId))
        XCTAssertEqual(viewModel.state.selectedCount, 0)
    }
    
    func testSelectAllReports() async {
        // Given
        let reportId1 = UUID()
        let reportId2 = UUID()
        viewModel.state.reports = [
            DomainPost(id: reportId1, date: Date(), goodItems: ["Тест 1"], badItems: [], published: true, voiceNotes: [], type: .external, isEvaluated: nil, evaluationResults: nil, authorUsername: "user1", authorFirstName: "User", authorLastName: "1", isExternal: true, externalVoiceNoteURLs: nil, externalText: "Отчет 1", externalMessageId: 1, authorId: 1),
            DomainPost(id: reportId2, date: Date(), goodItems: ["Тест 2"], badItems: [], published: true, voiceNotes: [], type: .external, isEvaluated: nil, evaluationResults: nil, authorUsername: "user2", authorFirstName: "User", authorLastName: "2", isExternal: true, externalVoiceNoteURLs: nil, externalText: "Отчет 2", externalMessageId: 2, authorId: 2)
        ]
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllReports)
        
        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(reportId1))
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(reportId2))
        XCTAssertEqual(viewModel.state.selectedCount, 2)
        XCTAssertTrue(viewModel.state.allSelected)
    }
    
    func testDeselectAllReports() async {
        // Given
        let reportId = UUID()
        viewModel.state.reports = [
            DomainPost(id: reportId, date: Date(), goodItems: ["Тест"], badItems: [], published: true, voiceNotes: [], type: .external, isEvaluated: nil, evaluationResults: nil, authorUsername: "test_user", authorFirstName: "Test", authorLastName: "User", isExternal: true, externalVoiceNoteURLs: nil, externalText: "Тестовый отчет", externalMessageId: 123, authorId: 456)
        ]
        viewModel.state.isSelectionMode = true
        viewModel.state.selectedReportIDs.insert(reportId)
        
        // When
        await viewModel.handle(.deselectAllReports)
        
        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
        XCTAssertEqual(viewModel.state.selectedCount, 0)
    }
    
    // MARK: - Delete Selected Reports Tests
    
    func testDeleteSelectedReports() async {
        // Given
        let reportId = UUID()
        let report = DomainPost(
            id: reportId,
            date: Date(),
            goodItems: ["Тест"],
            badItems: [],
            published: true,
            voiceNotes: [],
            type: .external,
            isEvaluated: nil,
            evaluationResults: nil,
            authorUsername: "test_user",
            authorFirstName: "Test",
            authorLastName: "User",
            isExternal: true,
            externalVoiceNoteURLs: nil,
            externalText: "Тестовый отчет",
            externalMessageId: 123,
            authorId: 456
        )
        viewModel.state.reports = [report]
        viewModel.state.isSelectionMode = true
        viewModel.state.selectedReportIDs.insert(reportId)
        
        // When
        await viewModel.handle(.deleteSelectedReports)
        
        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
        XCTAssertFalse(viewModel.state.isSelectionMode)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    // MARK: - Button States Tests
    
    func testUpdateButtonStates() async {
        // Given
        mockTelegramIntegrationService.telegramToken = "test_token"
        viewModel.state.reports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Тест"],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: "test_user",
                authorFirstName: "Test",
                authorLastName: "User",
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: "Тестовый отчет",
                externalMessageId: 123,
                authorId: 456
            )
        ]
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertTrue(viewModel.state.telegramConnected)
        XCTAssertTrue(viewModel.state.canClearHistory)
    }
    
    func testUpdateButtonStates_NoToken() async {
        // Given
        mockTelegramIntegrationService.telegramToken = nil
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.telegramConnected)
        XCTAssertFalse(viewModel.state.canClearHistory)
    }
}

// MARK: - Mock Classes

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
    
    func resetLastUpdateId() {
        self.lastUpdateId = nil
    }
    
    func refreshTelegramService() {}
    
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
        return Post(
            id: UUID(),
            date: Date(),
            goodItems: [],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .external,
            isEvaluated: nil,
            evaluationResults: nil,
            authorUsername: message.from?.username,
            authorFirstName: message.from?.firstName,
            authorLastName: message.from?.lastName,
            isExternal: true,
            externalVoiceNoteURLs: nil,
            externalText: message.text,
            externalMessageId: message.messageId,
            authorId: message.from?.id
        )
    }
    
    func getAllPosts() -> [Post] {
        return externalPosts
    }
    
    func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String {
        return "Mock formatted report"
    }
} 