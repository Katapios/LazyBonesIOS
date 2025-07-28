import XCTest
@testable import LazyBones

@MainActor
class ViewModelTests: XCTestCase {
    
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockSearchReportsUseCase: MockSearchReportsUseCase!
    var mockGetReportStatisticsUseCase: MockGetReportStatisticsUseCase!
    var mockGetReportsForDateUseCase: MockGetReportsForDateUseCase!
    var mockGetReportsByTypeUseCase: MockGetReportsByTypeUseCase!
    var reportsViewModel: ReportsViewModel!
    
    override func setUp() {
        super.setUp()
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockSearchReportsUseCase = MockSearchReportsUseCase()
        mockGetReportStatisticsUseCase = MockGetReportStatisticsUseCase()
        mockGetReportsForDateUseCase = MockGetReportsForDateUseCase()
        mockGetReportsByTypeUseCase = MockGetReportsByTypeUseCase()
        
        reportsViewModel = ReportsViewModel(
            getReportsUseCase: mockGetReportsUseCase,
            searchReportsUseCase: mockSearchReportsUseCase,
            getReportStatisticsUseCase: mockGetReportStatisticsUseCase,
            getReportsForDateUseCase: mockGetReportsForDateUseCase,
            getReportsByTypeUseCase: mockGetReportsByTypeUseCase
        )
    }
    
    override func tearDown() {
        mockGetReportsUseCase = nil
        mockSearchReportsUseCase = nil
        mockGetReportStatisticsUseCase = nil
        mockGetReportsForDateUseCase = nil
        mockGetReportsByTypeUseCase = nil
        reportsViewModel = nil
        super.tearDown()
    }
    
    // MARK: - ReportsViewModel Tests
    
    func testReportsViewModel_LoadReports_Success() async {
        // Given
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: [], badItems: ["Test"], published: false, voiceNotes: [], type: .custom)
        ]
        mockGetReportsUseCase.mockResult = expectedReports
        
        // When
        await reportsViewModel.loadReports()
        
        // Then
        XCTAssertFalse(reportsViewModel.isLoading)
        XCTAssertNil(reportsViewModel.errorMessage)
        XCTAssertEqual(reportsViewModel.reports.count, expectedReports.count)
        XCTAssertEqual(reportsViewModel.filteredReports.count, expectedReports.count)
    }
    
    func testReportsViewModel_LoadReports_Error() async {
        // Given
        mockGetReportsUseCase.shouldThrowError = true
        mockGetReportsUseCase.mockError = ReportRepositoryError.loadFailed
        
        // When
        await reportsViewModel.loadReports()
        
        // Then
        XCTAssertFalse(reportsViewModel.isLoading)
        XCTAssertNotNil(reportsViewModel.errorMessage)
        XCTAssertTrue(reportsViewModel.reports.isEmpty)
        XCTAssertTrue(reportsViewModel.filteredReports.isEmpty)
    }
    
    func testReportsViewModel_SearchReports_Success() async {
        // Given
        let searchQuery = "test"
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["test item"], badItems: [], published: true, voiceNotes: [], type: .regular)
        ]
        mockSearchReportsUseCase.mockResult = expectedReports
        reportsViewModel.searchText = searchQuery
        
        // When
        await reportsViewModel.searchReports()
        
        // Then
        XCTAssertFalse(reportsViewModel.isLoading)
        XCTAssertNil(reportsViewModel.errorMessage)
        XCTAssertEqual(reportsViewModel.reports.count, expectedReports.count)
        XCTAssertEqual(reportsViewModel.filteredReports.count, expectedReports.count)
        XCTAssertEqual(mockSearchReportsUseCase.lastSearchQuery, searchQuery)
    }
    
    func testReportsViewModel_SearchReports_EmptyQuery() async {
        // Given
        reportsViewModel.searchText = ""
        
        // When
        await reportsViewModel.searchReports()
        
        // Then
        // Should call loadReports instead of searchReports
        XCTAssertTrue(mockGetReportsUseCase.executeCalled)
    }
    
    func testReportsViewModel_LoadReportsForDate_Success() async {
        // Given
        let date = Date()
        let expectedReports = [
            Report(id: UUID(), date: date, goodItems: ["Test"], badItems: [], published: true, voiceNotes: [], type: .regular)
        ]
        mockGetReportsForDateUseCase.mockResult = expectedReports
        
        // When
        await reportsViewModel.loadReportsForDate(date)
        
        // Then
        XCTAssertFalse(reportsViewModel.isLoading)
        XCTAssertNil(reportsViewModel.errorMessage)
        XCTAssertEqual(reportsViewModel.reports.count, expectedReports.count)
        XCTAssertEqual(reportsViewModel.filteredReports.count, expectedReports.count)
        XCTAssertEqual(mockGetReportsForDateUseCase.lastDate, date)
    }
    
    func testReportsViewModel_LoadReportsByType_Success() async {
        // Given
        let type = ReportType.custom
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        mockGetReportsByTypeUseCase.mockResult = expectedReports
        
        // When
        await reportsViewModel.loadReportsByType(type)
        
        // Then
        XCTAssertFalse(reportsViewModel.isLoading)
        XCTAssertNil(reportsViewModel.errorMessage)
        XCTAssertEqual(reportsViewModel.reports.count, expectedReports.count)
        XCTAssertEqual(reportsViewModel.filteredReports.count, expectedReports.count)
        XCTAssertEqual(mockGetReportsByTypeUseCase.lastType, type)
    }
    
    func testReportsViewModel_LoadStatistics_Success() async {
        // Given
        let expectedStatistics = ReportStatistics(
            totalReports: 5,
            publishedReports: 3,
            unpublishedReports: 2,
            averageGoodItems: 2.0,
            averageBadItems: 1.0,
            mostCommonGoodItems: ["productive", "exercise"],
            mostCommonBadItems: ["procrastination"],
            reportsByType: [.regular: 3, .custom: 2],
            reportsByStatus: [.done: 3, .notStarted: 2]
        )
        mockGetReportStatisticsUseCase.mockResult = expectedStatistics
        
        // When
        await reportsViewModel.loadStatistics()
        
        // Then
        XCTAssertEqual(reportsViewModel.statistics?.totalReports, expectedStatistics.totalReports)
        XCTAssertEqual(reportsViewModel.statistics?.publishedReports, expectedStatistics.publishedReports)
        XCTAssertEqual(reportsViewModel.statistics?.unpublishedReports, expectedStatistics.unpublishedReports)
    }
    
    func testReportsViewModel_ApplyFilter() async {
        // Given
        let reports = [
            Report(id: UUID(), date: Date(), goodItems: ["good"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: [], badItems: ["bad"], published: false, voiceNotes: [], type: .custom)
        ]
        reportsViewModel.reports = reports
        
        let filter = ReportFilter(
            dateRange: nil,
            type: .regular,
            status: .done,
            isExternal: nil
        )
        
        // When
        reportsViewModel.applyFilter(filter)
        
        // Then
        XCTAssertEqual(reportsViewModel.selectedFilter, filter)
        XCTAssertEqual(reportsViewModel.filteredReports.count, 1) // Only published regular report
    }
    
    func testReportsViewModel_ClearFilter() async {
        // Given
        let reports = [
            Report(id: UUID(), date: Date(), goodItems: ["good"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: [], badItems: ["bad"], published: false, voiceNotes: [], type: .custom)
        ]
        reportsViewModel.reports = reports
        reportsViewModel.selectedFilter = ReportFilter(
            dateRange: nil,
            type: .regular,
            status: .done,
            isExternal: nil
        )
        
        // When
        reportsViewModel.clearFilter()
        
        // Then
        XCTAssertNil(reportsViewModel.selectedFilter)
        XCTAssertEqual(reportsViewModel.filteredReports.count, 2) // All reports
    }
    
    func testReportsViewModel_ComputedProperties() async {
        // Given
        let reports = [
            Report(id: UUID(), date: Date(), goodItems: ["good"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: [], badItems: ["bad"], published: false, voiceNotes: [], type: .custom)
        ]
        reportsViewModel.reports = reports
        reportsViewModel.applyFilter(nil) // Clear filter to show all reports
        
        // When & Then
        XCTAssertEqual(reportsViewModel.reportsCount, 2)
        XCTAssertEqual(reportsViewModel.publishedReportsCount, 1)
        XCTAssertEqual(reportsViewModel.unpublishedReportsCount, 1)
        XCTAssertFalse(reportsViewModel.hasError)
        XCTAssertTrue(reportsViewModel.hasReports)
    }
    
    func testReportsViewModel_GroupedReports() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let reports = [
            Report(id: UUID(), date: today, goodItems: ["good1"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: today, goodItems: ["good2"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: yesterday, goodItems: ["good3"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        reportsViewModel.reports = reports
        reportsViewModel.applyFilter(nil) // Clear filter to show all reports
        
        // When
        let groupedReports = reportsViewModel.groupedReports
        
        // Then
        XCTAssertEqual(groupedReports.count, 2) // Two different dates
        XCTAssertEqual(groupedReports.values.first?.count, 2) // Two reports for today
        XCTAssertEqual(groupedReports.values.last?.count, 1) // One report for yesterday
    }
}

// MARK: - Mock Use Cases

class MockGetReportsUseCase: GetReportsUseCase {
    var mockResult: [Report] = []
    var shouldThrowError = false
    var mockError: Error = ReportRepositoryError.loadFailed
    var executeCalled = false
    
    override func execute() async throws -> [Report] {
        executeCalled = true
        if shouldThrowError {
            throw mockError
        }
        return mockResult
    }
}

class MockSearchReportsUseCase: SearchReportsUseCase {
    var mockResult: [Report] = []
    var shouldThrowError = false
    var mockError: Error = ReportRepositoryError.loadFailed
    var lastSearchQuery: String?
    
    override func execute(input: String) async throws -> [Report] {
        lastSearchQuery = input
        if shouldThrowError {
            throw mockError
        }
        return mockResult
    }
}

class MockGetReportStatisticsUseCase: GetReportStatisticsUseCase {
    var mockResult: ReportStatistics!
    var shouldThrowError = false
    var mockError: Error = ReportRepositoryError.loadFailed
    
    override func execute() async throws -> ReportStatistics {
        if shouldThrowError {
            throw mockError
        }
        return mockResult
    }
}

class MockGetReportsForDateUseCase: GetReportsForDateUseCase {
    var mockResult: [Report] = []
    var shouldThrowError = false
    var mockError: Error = ReportRepositoryError.loadFailed
    var lastDate: Date?
    
    override func execute(input: Date) async throws -> [Report] {
        lastDate = input
        if shouldThrowError {
            throw mockError
        }
        return mockResult
    }
}

class MockGetReportsByTypeUseCase: GetReportsByTypeUseCase {
    var mockResult: [Report] = []
    var shouldThrowError = false
    var mockError: Error = ReportRepositoryError.loadFailed
    var lastType: ReportType?
    
    override func execute(input: ReportType) async throws -> [Report] {
        lastType = input
        if shouldThrowError {
            throw mockError
        }
        return mockResult
    }
} 