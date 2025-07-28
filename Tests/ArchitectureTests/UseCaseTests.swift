import XCTest
@testable import LazyBones

class UseCaseTests: XCTestCase {
    
    var mockRepository: MockReportRepository!
    var getReportsUseCase: GetReportsUseCase!
    var searchReportsUseCase: SearchReportsUseCase!
    var getReportStatisticsUseCase: GetReportStatisticsUseCase!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockReportRepository()
        getReportsUseCase = GetReportsUseCase(repository: mockRepository)
        searchReportsUseCase = SearchReportsUseCase(repository: mockRepository)
        getReportStatisticsUseCase = GetReportStatisticsUseCase(repository: mockRepository)
    }
    
    override func tearDown() {
        mockRepository = nil
        getReportsUseCase = nil
        searchReportsUseCase = nil
        getReportStatisticsUseCase = nil
        super.tearDown()
    }
    
    // MARK: - GetReportsUseCase Tests
    
    func testGetReportsUseCase_Success() async throws {
        // Given
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: [], badItems: ["Test"], published: false, voiceNotes: [], type: .custom)
        ]
        mockRepository.mockReports = expectedReports
        
        // When
        let result = try await getReportsUseCase.execute()
        
        // Then
        XCTAssertEqual(result.count, expectedReports.count)
        XCTAssertEqual(result, expectedReports)
    }
    
    func testGetReportsUseCase_Error() async {
        // Given
        mockRepository.shouldThrowError = true
        
        // When & Then
        do {
            _ = try await getReportsUseCase.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ReportRepositoryError)
        }
    }
    
    // MARK: - SearchReportsUseCase Tests
    
    func testSearchReportsUseCase_Success() async throws {
        // Given
        let searchQuery = "test"
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["test item"], badItems: [], published: true, voiceNotes: [], type: .regular)
        ]
        mockRepository.mockReports = expectedReports
        
        // When
        let result = try await searchReportsUseCase.execute(input: searchQuery)
        
        // Then
        XCTAssertEqual(result.count, expectedReports.count)
        XCTAssertEqual(result, expectedReports)
    }
    
    func testSearchReportsUseCase_EmptyQuery() async throws {
        // Given
        let searchQuery = ""
        let expectedReports = [
            Report(id: UUID(), date: Date(), goodItems: ["item"], badItems: [], published: true, voiceNotes: [], type: .regular)
        ]
        mockRepository.mockReports = expectedReports
        
        // When
        let result = try await searchReportsUseCase.execute(input: searchQuery)
        
        // Then
        XCTAssertEqual(result.count, expectedReports.count)
    }
    
    // MARK: - GetReportStatisticsUseCase Tests
    
    func testGetReportStatisticsUseCase_Success() async throws {
        // Given
        let reports = [
            Report(id: UUID(), date: Date(), goodItems: ["good1", "good2"], badItems: ["bad1"], published: true, voiceNotes: [], type: .regular),
            Report(id: UUID(), date: Date(), goodItems: ["good3"], badItems: ["bad2", "bad3"], published: false, voiceNotes: [], type: .custom)
        ]
        mockRepository.mockReports = reports
        
        // When
        let result = try await getReportStatisticsUseCase.execute()
        
        // Then
        XCTAssertEqual(result.totalReports, 2)
        XCTAssertEqual(result.publishedReports, 1)
        XCTAssertEqual(result.unpublishedReports, 1)
        XCTAssertEqual(result.averageGoodItems, 1.5)
        XCTAssertEqual(result.averageBadItems, 1.5)
    }
    
    func testGetReportStatisticsUseCase_EmptyReports() async throws {
        // Given
        mockRepository.mockReports = []
        
        // When
        let result = try await getReportStatisticsUseCase.execute()
        
        // Then
        XCTAssertEqual(result.totalReports, 0)
        XCTAssertEqual(result.publishedReports, 0)
        XCTAssertEqual(result.unpublishedReports, 0)
        XCTAssertEqual(result.averageGoodItems, 0)
        XCTAssertEqual(result.averageBadItems, 0)
    }
}

// MARK: - Mock Repository

class MockReportRepository: ReportRepositoryProtocol {
    
    var mockReports: [Report] = []
    var shouldThrowError = false
    var lastSearchQuery: String?
    var lastDateFilter: Date?
    var lastTypeFilter: ReportType?
    
    func fetch() async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports
    }
    
    func save(_ models: [Report]) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.saveFailed
        }
        mockReports = models
    }
    
    func delete(_ model: Report) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.deleteFailed
        }
        mockReports.removeAll { $0.id == model.id }
    }
    
    func clear() async throws {
        if shouldThrowError {
            throw ReportRepositoryError.deleteFailed
        }
        mockReports.removeAll()
    }
    
    func create(_ model: Report) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.saveFailed
        }
        mockReports.append(model)
    }
    
    func read(id: String) async throws -> Report? {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        guard let uuid = UUID(uuidString: id) else {
            throw ReportRepositoryError.invalidReportData
        }
        return mockReports.first { $0.id == uuid }
    }
    
    func update(_ model: Report) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.saveFailed
        }
        if let index = mockReports.firstIndex(where: { $0.id == model.id }) {
            mockReports[index] = model
        }
    }
    
    func search(query: String) async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        lastSearchQuery = query
        return mockReports.filter { report in
            report.goodItems.contains { $0.lowercased().contains(query.lowercased()) } ||
            report.badItems.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    func filter(predicate: @escaping (Report) -> Bool) async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports.filter(predicate)
    }
    
    func getReportsForDate(_ date: Date) async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        lastDateFilter = date
        return mockReports.filter { DateUtils.isSameDay($0.date, date) }
    }
    
    func getReportsForDateRange(from: Date, to: Date) async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports.filter { $0.date >= from && $0.date <= to }
    }
    
    func getPublishedReports() async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports.filter { $0.published }
    }
    
    func getUnpublishedReports() async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports.filter { !$0.published }
    }
    
    func getReportsByType(_ type: ReportType) async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        lastTypeFilter = type
        return mockReports.filter { $0.type == type }
    }
    
    func getExternalReports() async throws -> [Report] {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        return mockReports.filter { $0.isExternal == true }
    }
    
    func publishReport(_ report: Report) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.saveFailed
        }
        // Mock implementation
    }
    
    func unpublishReport(_ report: Report) async throws {
        if shouldThrowError {
            throw ReportRepositoryError.saveFailed
        }
        // Mock implementation
    }
    
    func getReportStatistics() async throws -> ReportStatistics {
        if shouldThrowError {
            throw ReportRepositoryError.loadFailed
        }
        
        let totalReports = mockReports.count
        let publishedReports = mockReports.filter { $0.published }.count
        let unpublishedReports = totalReports - publishedReports
        
        let averageGoodItems = totalReports > 0 ? Double(mockReports.reduce(0) { $0 + $1.goodItems.count }) / Double(totalReports) : 0
        let averageBadItems = totalReports > 0 ? Double(mockReports.reduce(0) { $0 + $1.badItems.count }) / Double(totalReports) : 0
        
        let allGoodItems = mockReports.flatMap { $0.goodItems }
        let allBadItems = mockReports.flatMap { $0.badItems }
        
        let mostCommonGoodItems = Array(Set(allGoodItems)).prefix(5).map { $0 }
        let mostCommonBadItems = Array(Set(allBadItems)).prefix(5).map { $0 }
        
        var reportsByType: [ReportType: Int] = [:]
        for type in ReportType.allCases {
            reportsByType[type] = mockReports.filter { $0.type == type }.count
        }
        
        var reportsByStatus: [ReportStatus: Int] = [:]
        reportsByStatus[.done] = publishedReports
        reportsByStatus[.notStarted] = unpublishedReports
        reportsByStatus[.inProgress] = 0
        
        return ReportStatistics(
            totalReports: totalReports,
            publishedReports: publishedReports,
            unpublishedReports: unpublishedReports,
            averageGoodItems: averageGoodItems,
            averageBadItems: averageBadItems,
            mostCommonGoodItems: Array(mostCommonGoodItems),
            mostCommonBadItems: Array(mostCommonBadItems),
            reportsByType: reportsByType,
            reportsByStatus: reportsByStatus
        )
    }
} 