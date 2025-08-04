import XCTest
@testable import LazyBones

@MainActor
class ExternalReportsIntegrationTests: XCTestCase {
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    var mockTelegramIntegrationService: MockTelegramIntegrationService!
    var viewModel: ExternalReportsViewModel!
    
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
        mockGetReportsUseCase = nil
        mockDeleteReportUseCase = nil
        mockTelegramIntegrationService = nil
        viewModel = nil
        super.tearDown()
    }
    
    func testLoadReportsIntegration() async {
        // Given
        let testReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Тестовая задача 1"],
                badItems: ["Невыполненная задача"],
                voiceNote: nil,
                tags: ["тест"]
            )
        ]
        mockGetReportsUseCase.mockResult = .success(testReports)
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
        XCTAssertFalse(viewModel.state.showEmptyState)
    }
    
    func testRefreshFromTelegramIntegration() async {
        // Given
        mockTelegramIntegrationService.telegramToken = "test_token"
        mockTelegramIntegrationService.fetchExternalPostsResult = true
        
        // When
        await viewModel.handle(.refreshFromTelegram)
        
        // Then
        XCTAssertFalse(viewModel.state.isRefreshing)
        XCTAssertTrue(mockTelegramIntegrationService.fetchExternalPostsCalled)
    }
    
    func testClearHistoryIntegration() async {
        // Given
        let testReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Задача для удаления"],
                badItems: [],
                voiceNote: nil,
                tags: []
            )
        ]
        viewModel.state.reports = testReports
        mockTelegramIntegrationService.deleteAllBotMessagesResult = true
        
        // When
        await viewModel.handle(.clearHistory)
        
        // Then
        XCTAssertTrue(mockTelegramIntegrationService.deleteAllBotMessagesCalled)
        XCTAssertTrue(viewModel.state.reports.isEmpty)
    }
    
    func testSelectionModeIntegration() async {
        // Given
        let testReportId = UUID()
        let testReports = [
            DomainPost(
                id: testReportId,
                date: Date(),
                goodItems: ["Задача для выбора"],
                badItems: [],
                voiceNote: nil,
                tags: []
            )
        ]
        viewModel.state.reports = testReports
        
        // When
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertTrue(viewModel.state.isSelectionMode)
        
        // When
        await viewModel.handle(.selectReport(testReportId))
        
        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(testReportId))
        XCTAssertEqual(viewModel.state.selectedReportsCount, 1)
    }
    
    func testSelectAllReportsIntegration() async {
        // Given
        let testReports = [
            DomainPost(id: UUID(), date: Date(), goodItems: ["Задача 1"], badItems: [], voiceNote: nil, tags: []),
            DomainPost(id: UUID(), date: Date(), goodItems: ["Задача 2"], badItems: [], voiceNote: nil, tags: [])
        ]
        viewModel.state.reports = testReports
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedReportsCount, 2)
        XCTAssertEqual(viewModel.state.selectedReportIDs.count, 2)
    }
    
    func testDeleteSelectedReportsIntegration() async {
        // Given
        let testReportId = UUID()
        let testReports = [
            DomainPost(
                id: testReportId,
                date: Date(),
                goodItems: ["Задача для удаления"],
                badItems: [],
                voiceNote: nil,
                tags: []
            )
        ]
        viewModel.state.reports = testReports
        viewModel.state.selectedReportIDs = [testReportId]
        mockDeleteReportUseCase.mockResult = .success(())
        
        // When
        await viewModel.handle(.deleteSelectedReports)
        
        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
        XCTAssertFalse(viewModel.state.isSelectionMode)
    }
    
    func testErrorHandlingIntegration() async {
        // Given
        mockGetReportsUseCase.mockResult = .failure(.repositoryError)
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertNotNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
    }
} 