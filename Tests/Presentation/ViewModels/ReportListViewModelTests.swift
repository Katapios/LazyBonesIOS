import XCTest
@testable import LazyBones

@MainActor
class ReportListViewModelTests: XCTestCase {
    
    var viewModel: ReportListViewModel!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    
    override func setUp() {
        super.setUp()
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockDeleteReportUseCase = MockDeleteReportUseCase()
        viewModel = ReportListViewModel(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockGetReportsUseCase = nil
        mockDeleteReportUseCase = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 0)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
        XCTAssertEqual(viewModel.state.selectedDate, Date())
        XCTAssertNil(viewModel.state.filterType)
        XCTAssertTrue(viewModel.state.showExternalReports)
    }
    
    func testLoadReports_Success() async {
        // Given
        let mockReports = [
            DomainPost(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: true, voiceNotes: [], type: .regular),
            DomainPost(id: UUID(), date: Date(), goodItems: [], badItems: ["Не спал"], published: true, voiceNotes: [], type: .custom)
        ]
        mockGetReportsUseCase.mockResult = .success(mockReports)
        
        // When
        await viewModel.load()
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 2)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testLoadReports_Error() async {
        // Given
        let mockError = GetReportsError.repositoryError(NSError(domain: "test", code: 1))
        mockGetReportsUseCase.mockResult = .failure(mockError)
        
        // When
        await viewModel.load()
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 0)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.error)
    }
    
    func testHandleLoadReports() async {
        // Given
        let mockReports = [DomainPost(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: true, voiceNotes: [], type: .regular)]
        mockGetReportsUseCase.mockResult = .success(mockReports)
        
        // When
        viewModel.handle(.loadReports)
        
        // Wait for async operation
        await Task.sleep(100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
    }
    
    func testHandleSelectDate() {
        // Given
        let newDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // When
        viewModel.handle(.selectDate(newDate))
        
        // Then
        XCTAssertEqual(viewModel.state.selectedDate, newDate)
    }
    
    func testHandleFilterByType() {
        // Given
        let filterType = PostType.custom
        
        // When
        viewModel.handle(.filterByType(filterType))
        
        // Then
        XCTAssertEqual(viewModel.state.filterType, filterType)
    }
    
    func testHandleToggleExternalReports() {
        // Given
        XCTAssertTrue(viewModel.state.showExternalReports)
        
        // When
        viewModel.handle(.toggleExternalReports)
        
        // Then
        XCTAssertFalse(viewModel.state.showExternalReports)
    }
}

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