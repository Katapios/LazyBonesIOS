import XCTest
import SwiftUI
@testable import LazyBones

@MainActor
class ExternalReportsViewTests: XCTestCase {
    // Локальные моки для новых UseCase
    final class MockGetExternalReportsUseCase: GetExternalReportsUseCaseProtocol {
        var result: Result<[DomainPost], GetReportsError> = .success([])
        func execute(input: GetExternalReportsInput) async throws -> [DomainPost] {
            switch result {
            case .success(let reports): return reports
            case .failure(let error): throw error
            }
        }
    }
    
    final class MockRefreshExternalReportsUseCase: RefreshExternalReportsUseCaseProtocol {
        func execute() async throws { /* no-op */ }
    }
    
    var mockGetExternalReportsUseCase: MockGetExternalReportsUseCase!
    var mockRefreshExternalReportsUseCase: MockRefreshExternalReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    var mockTelegramIntegrationService: MockTelegramIntegrationService!
    
    override func setUp() {
        super.setUp()
        mockGetExternalReportsUseCase = MockGetExternalReportsUseCase()
        mockRefreshExternalReportsUseCase = MockRefreshExternalReportsUseCase()
        mockDeleteReportUseCase = MockDeleteReportUseCase()
        mockTelegramIntegrationService = MockTelegramIntegrationService()
    }
    
    override func tearDown() {
        mockGetExternalReportsUseCase = nil
        mockRefreshExternalReportsUseCase = nil
        mockDeleteReportUseCase = nil
        mockTelegramIntegrationService = nil
        super.tearDown()
    }
    
    func testExternalReportsViewInitialization() {
        // Given
        let view = ExternalReportsView(
            getExternalReportsUseCase: mockGetExternalReportsUseCase,
            refreshExternalReportsUseCase: mockRefreshExternalReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
    
    func testExternalReportsViewWithEmptyReports() {
        // Given
        mockGetExternalReportsUseCase.result = .success([])
        mockTelegramIntegrationService.telegramToken = nil
        
        let view = ExternalReportsView(
            getExternalReportsUseCase: mockGetExternalReportsUseCase,
            refreshExternalReportsUseCase: mockRefreshExternalReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
    
    func testExternalReportsViewWithReports() {
        // Given
        let testReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Выполнил задачу 1"],
                badItems: ["Не выполнил задачу 2"],
                published: false,
                voiceNotes: [],
                type: .external
            ),
            DomainPost(
                id: UUID(),
                date: Date().addingTimeInterval(-86400),
                goodItems: ["Выполнил задачу 3"],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external
            )
        ]
        
        mockGetExternalReportsUseCase.result = .success(testReports)
        mockTelegramIntegrationService.telegramToken = "test_token"
        
        let view = ExternalReportsView(
            getExternalReportsUseCase: mockGetExternalReportsUseCase,
            refreshExternalReportsUseCase: mockRefreshExternalReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
    
    func testExternalReportsViewWithError() {
        // Given
        mockGetExternalReportsUseCase.result = .failure(.repositoryError(NSError(domain: "Test", code: 1)))
        mockTelegramIntegrationService.telegramToken = "test_token"
        
        let view = ExternalReportsView(
            getExternalReportsUseCase: mockGetExternalReportsUseCase,
            refreshExternalReportsUseCase: mockRefreshExternalReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
}
 