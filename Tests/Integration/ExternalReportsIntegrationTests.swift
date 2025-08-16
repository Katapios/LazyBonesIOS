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

// MARK: - Local Mocks

final class MockGetReportsUseCase: GetReportsUseCaseProtocol {
    var mockResult: Result<[DomainPost], GetReportsError> = .success([])
    func execute(input: GetReportsInput) async throws -> [DomainPost] {
        switch mockResult {
        case .success(let posts): return posts
        case .failure(let err): throw err
        }
    }
}

final class MockDeleteReportUseCase: DeleteReportUseCaseProtocol {
    typealias ErrorType = DeleteReportError
    var mockResult: Result<Void, DeleteReportError> = .success(())
    func execute(input: DeleteReportInput) async throws -> Void {
        switch mockResult {
        case .success: return ()
        case .failure(let err): throw err
        }
    }
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
                published: false,
                voiceNotes: [],
                type: .external
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
                published: false,
                voiceNotes: [],
                type: .external
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
                published: false,
                voiceNotes: [],
                type: .external
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
        XCTAssertEqual(viewModel.state.selectedCount, 1)
    }
    
    func testSelectAllReportsIntegration() async {
        // Given
        let testReports = [
            DomainPost(id: UUID(), date: Date(), goodItems: ["Задача 1"], badItems: [], published: false, voiceNotes: [], type: .external),
            DomainPost(id: UUID(), date: Date(), goodItems: ["Задача 2"], badItems: [], published: false, voiceNotes: [], type: .external)
        ]
        viewModel.state.reports = testReports
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedCount, 2)
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
                published: false,
                voiceNotes: [],
                type: .external
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
        mockGetReportsUseCase.mockResult = .failure(.repositoryError(NSError(domain: "test", code: 1)))
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertNotNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
    }
} 