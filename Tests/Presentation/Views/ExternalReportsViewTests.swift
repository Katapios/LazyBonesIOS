import XCTest
import SwiftUI
@testable import LazyBones

@MainActor
class ExternalReportsViewTests: XCTestCase {
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    var mockTelegramIntegrationService: MockTelegramIntegrationService!
    
    override func setUp() {
        super.setUp()
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockDeleteReportUseCase = MockDeleteReportUseCase()
        mockTelegramIntegrationService = MockTelegramIntegrationService()
    }
    
    override func tearDown() {
        mockGetReportsUseCase = nil
        mockDeleteReportUseCase = nil
        mockTelegramIntegrationService = nil
        super.tearDown()
    }
    
    func testExternalReportsViewInitialization() {
        // Given
        let view = ExternalReportsView(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
    
    func testExternalReportsViewWithEmptyReports() {
        // Given
        mockGetReportsUseCase.mockResult = .success([])
        mockTelegramIntegrationService.telegramToken = nil
        
        let view = ExternalReportsView(
            getReportsUseCase: mockGetReportsUseCase,
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
        
        mockGetReportsUseCase.mockResult = .success(testReports)
        mockTelegramIntegrationService.telegramToken = "test_token"
        
        let view = ExternalReportsView(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
    
    func testExternalReportsViewWithError() {
        // Given
        mockGetReportsUseCase.mockResult = .failure(.repositoryError(NSError(domain: "Test", code: 1)))
        mockTelegramIntegrationService.telegramToken = "test_token"
        
        let view = ExternalReportsView(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            telegramIntegrationService: mockTelegramIntegrationService
        )
        
        // Then
        XCTAssertNotNil(view)
    }
} 