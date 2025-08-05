import XCTest
@testable import LazyBones

@MainActor
final class ReportsViewModelNewTests: XCTestCase {
    
    var viewModel: ReportsViewModelNew!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockDeleteReportUseCase: MockDeleteReportUseCase!
    var mockUpdateReportUseCase: MockUpdateReportUseCase!
    var mockTagRepository: MockTagRepository!
    
    override func setUp() {
        super.setUp()
        
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockDeleteReportUseCase = MockDeleteReportUseCase()
        mockUpdateReportUseCase = MockUpdateReportUseCase()
        mockTagRepository = MockTagRepository()
        
        viewModel = ReportsViewModelNew(
            getReportsUseCase: mockGetReportsUseCase,
            deleteReportUseCase: mockDeleteReportUseCase,
            updateReportUseCase: mockUpdateReportUseCase,
            tagRepository: mockTagRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockGetReportsUseCase = nil
        mockDeleteReportUseCase = nil
        mockUpdateReportUseCase = nil
        mockTagRepository = nil
        super.tearDown()
    }
    
    // MARK: - Load Reports Tests
    
    func testLoadReports_Success() async {
        // Given
        let regularReports = [DomainPost.mockRegular(), DomainPost.mockRegular()]
        let customReports = [DomainPost.mockCustom()]
        let externalReports = [DomainPost.mockExternal()]
        
        mockGetReportsUseCase.mockRegularReports = regularReports
        mockGetReportsUseCase.mockCustomReports = customReports
        mockGetReportsUseCase.mockExternalReports = externalReports
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertEqual(viewModel.state.regularReports.count, 2)
        XCTAssertEqual(viewModel.state.customReports.count, 1)
        XCTAssertEqual(viewModel.state.externalReports.count, 1)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testLoadReports_Error() async {
        // Given
        let error = NSError(domain: "Test", code: 1, userInfo: nil)
        mockGetReportsUseCase.shouldThrowError = true
        mockGetReportsUseCase.mockError = error
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertTrue(viewModel.state.regularReports.isEmpty)
        XCTAssertTrue(viewModel.state.customReports.isEmpty)
        XCTAssertTrue(viewModel.state.externalReports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.error)
    }
    
    // MARK: - Selection Tests
    
    func testToggleSelectionMode() async {
        // Given
        XCTAssertFalse(viewModel.state.isSelectionMode)
        
        // When
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertTrue(viewModel.state.isSelectionMode)
    }
    
    func testToggleSelection() async {
        // Given
        let reportId = UUID()
        XCTAssertFalse(viewModel.state.selectedLocalReportIDs.contains(reportId))
        
        // When
        await viewModel.handle(.toggleSelection(reportId))
        
        // Then
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.contains(reportId))
        
        // When - toggle again
        await viewModel.handle(.toggleSelection(reportId))
        
        // Then
        XCTAssertFalse(viewModel.state.selectedLocalReportIDs.contains(reportId))
    }
    
    func testSelectAllRegularReports() async {
        // Given
        let regularReports = [DomainPost.mockRegular(), DomainPost.mockRegular()]
        viewModel.state.regularReports = regularReports
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllRegularReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedLocalReportIDs.count, 2)
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.contains(regularReports[0].id))
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.contains(regularReports[1].id))
    }
    
    func testSelectAllCustomReports() async {
        // Given
        let customReports = [DomainPost.mockCustom(), DomainPost.mockCustom()]
        viewModel.state.customReports = customReports
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllCustomReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedLocalReportIDs.count, 2)
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.contains(customReports[0].id))
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.contains(customReports[1].id))
    }
    
    // MARK: - Delete Tests
    
    func testDeleteSelectedReports() async {
        // Given
        let regularReport = DomainPost.mockRegular()
        let customReport = DomainPost.mockCustom()
        viewModel.state.regularReports = [regularReport]
        viewModel.state.customReports = [customReport]
        viewModel.state.selectedLocalReportIDs = [regularReport.id, customReport.id]
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.deleteSelectedReports)
        
        // Then
        XCTAssertTrue(viewModel.state.regularReports.isEmpty)
        XCTAssertTrue(viewModel.state.customReports.isEmpty)
        XCTAssertTrue(viewModel.state.selectedLocalReportIDs.isEmpty)
        XCTAssertFalse(viewModel.state.isSelectionMode)
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    // MARK: - Evaluation Tests
    
    func testStartEvaluation() async {
        // Given
        let report = DomainPost.mockRegular()
        
        // When
        await viewModel.handle(.startEvaluation(report))
        
        // Then
        XCTAssertTrue(viewModel.state.showEvaluationSheet)
        XCTAssertEqual(viewModel.state.evaluatingPost?.id, report.id)
    }
    
    func testCompleteEvaluation() async {
        // Given
        let report = DomainPost.mockRegular()
        viewModel.state.evaluatingPost = report
        viewModel.state.regularReports = [report]
        let results = [true, false, true]
        
        // When
        await viewModel.handle(.completeEvaluation(results))
        
        // Then
        XCTAssertFalse(viewModel.state.showEvaluationSheet)
        XCTAssertNil(viewModel.state.evaluatingPost)
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    // MARK: - Settings Tests
    
    func testUpdateReevaluationSettings() async {
        // Given
        XCTAssertFalse(viewModel.state.allowCustomReportReevaluation)
        
        // When
        await viewModel.handle(.updateReevaluationSettings(true))
        
        // Then
        XCTAssertTrue(viewModel.state.allowCustomReportReevaluation)
    }
    
    // MARK: - Computed Properties Tests
    
    func testComputedProperties() {
        // Given
        let regularReport = DomainPost.mockRegular()
        let customReport = DomainPost.mockCustom()
        viewModel.state.regularReports = [regularReport]
        viewModel.state.customReports = [customReport]
        viewModel.state.selectedLocalReportIDs = [regularReport.id]
        
        // Then
        XCTAssertTrue(viewModel.state.hasRegularPosts)
        XCTAssertTrue(viewModel.state.hasCustomPosts)
        XCTAssertEqual(viewModel.state.selectedReportsCount, 1)
        XCTAssertTrue(viewModel.state.hasSelectedReports)
        XCTAssertEqual(viewModel.state.selectedRegularPosts.count, 1)
        XCTAssertEqual(viewModel.state.selectedCustomPosts.count, 0)
    }
    
    func testCanDeleteReports() {
        // Given
        let report = DomainPost.mockRegular()
        viewModel.state.regularReports = [report]
        viewModel.state.selectedLocalReportIDs = [report.id]
        
        // When - selection mode off
        viewModel.state.isSelectionMode = false
        
        // Then
        XCTAssertFalse(viewModel.state.canDeleteReports)
        
        // When - selection mode on
        viewModel.state.isSelectionMode = true
        
        // Then
        XCTAssertTrue(viewModel.state.canDeleteReports)
    }
    
    // MARK: - Public Methods Tests
    
    func testCanEvaluateReport() {
        // Given
        let todayReport = DomainPost.mockRegular()
        let oldReport = DomainPost.mockRegular()
        oldReport.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // When & Then
        XCTAssertTrue(viewModel.canEvaluateReport(todayReport))
        XCTAssertFalse(viewModel.canEvaluateReport(oldReport))
        
        // When - selection mode on
        viewModel.state.isSelectionMode = true
        
        // Then
        XCTAssertFalse(viewModel.canEvaluateReport(todayReport))
    }
    
    func testIsReportEvaluated() {
        // Given
        let evaluatedReport = DomainPost.mockRegular()
        evaluatedReport.isEvaluated = true
        
        // When - reevaluation disabled
        viewModel.state.allowCustomReportReevaluation = false
        
        // Then
        XCTAssertTrue(viewModel.isReportEvaluated(evaluatedReport))
        
        // When - reevaluation enabled
        viewModel.state.allowCustomReportReevaluation = true
        
        // Then
        XCTAssertFalse(viewModel.isReportEvaluated(evaluatedReport))
    }
}

// MARK: - Mock Objects

class MockGetReportsUseCase: GetReportsUseCase {
    var mockRegularReports: [DomainPost] = []
    var mockCustomReports: [DomainPost] = []
    var mockExternalReports: [DomainPost] = []
    var shouldThrowError = false
    var mockError: Error?
    
    override func execute(input: GetReportsInput) async throws -> [DomainPost] {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
        
        switch input.type {
        case .regular:
            return mockRegularReports
        case .custom:
            return mockCustomReports
        case nil:
            return mockExternalReports
        }
    }
}

class MockDeleteReportUseCase: DeleteReportUseCase {
    var shouldThrowError = false
    var mockError: Error?
    
    override func execute(input: DeleteReportInput) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
}

class MockUpdateReportUseCase: UpdateReportUseCase {
    var shouldThrowError = false
    var mockError: Error?
    
    override func execute(input: UpdateReportInput) async throws -> DomainPost {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return input.report
    }
}

class MockTagRepository: TagRepositoryProtocol {
    var mockGoodTags: [String] = ["Good1", "Good2"]
    var mockBadTags: [String] = ["Bad1", "Bad2"]
    var shouldThrowError = false
    var mockError: Error?
    
    func saveGoodTags(_ tags: [String]) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func saveBadTags(_ tags: [String]) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func loadGoodTags() async throws -> [String] {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return mockGoodTags
    }
    
    func loadBadTags() async throws -> [String] {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return mockBadTags
    }
    
    func addGoodTag(_ tag: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func addBadTag(_ tag: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func removeGoodTag(_ tag: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func removeBadTag(_ tag: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func updateGoodTag(old: String, new: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
    
    func updateBadTag(old: String, new: String) async throws {
        if shouldThrowError {
            throw mockError ?? NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
} 