import XCTest
@testable import LazyBones

@MainActor
class CustomReportsViewModelTests: XCTestCase {

    var viewModel: CustomReportsViewModel!
    var mockCreateUseCase: CreateReportUseCase!
    var mockGetUseCase: GetReportsUseCase!
    var mockDeleteUseCase: DeleteReportUseCase!
    var mockUpdateReportUseCase: UpdateReportUseCase!
    fileprivate var mockRepository: MockPostRepository!

    override func setUp() {
        super.setUp()
        // Создаем реальные Use Cases с мок репозиториями
        mockRepository = MockPostRepository()
        _ = MockSettingsRepository()

        mockCreateUseCase = CreateReportUseCase(postRepository: mockRepository)
        mockGetUseCase = GetReportsUseCase(postRepository: mockRepository)
        mockDeleteUseCase = DeleteReportUseCase(postRepository: mockRepository)
        mockUpdateReportUseCase = UpdateReportUseCase(postRepository: mockRepository)

        viewModel = CustomReportsViewModel(
            createReportUseCase: mockCreateUseCase,
            getReportsUseCase: mockGetUseCase,
            deleteReportUseCase: mockDeleteUseCase,
            updateReportUseCase: mockUpdateReportUseCase
        )
    }

    override func tearDown() {
        viewModel = nil
        mockCreateUseCase = nil
        mockGetUseCase = nil
        mockDeleteUseCase = nil
        mockUpdateReportUseCase = nil
        super.tearDown()
    }

    // MARK: - Load Reports Tests

    func testLoadReports_Success() async {
        // Given
        let expectedReports = [
            DomainPost(goodItems: ["Пункт 1", "Пункт 2"], badItems: [], type: .custom),
            DomainPost(goodItems: ["Пункт 3"], badItems: ["Пропустил"], type: .custom)
        ]
        mockRepository.posts = expectedReports

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertEqual(viewModel.state.reports.count, 2)
        XCTAssertEqual(viewModel.state.reports.first?.type, .custom)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }

    func testLoadReports_Error() async {
        // Given
        mockRepository.shouldThrowError = true

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.error)
    }

    // MARK: - Create Report Tests

    func testCreateReport_Success() async {
        // Given
        let goodItems = ["Пункт 1", "Пункт 2"]
        let badItems = ["Пропустил"]

        // When
        await viewModel.handle(.createReport(goodItems: goodItems, badItems: badItems))

        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reports.first?.type, .custom)
        XCTAssertEqual(viewModel.state.reports.first?.goodItems, goodItems)
        XCTAssertEqual(viewModel.state.reports.first?.badItems, badItems)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }

    // MARK: - Evaluate Report Tests

    func testEvaluateReport_Success() async {
        // Given
        let report = DomainPost(goodItems: ["Пункт 1", "Пункт 2"], badItems: [], type: .custom)
        let results = [true, false]
        
        // Добавляем отчет в состояние
        viewModel.state.reports = [report]

        // When
        await viewModel.handle(.evaluateReport(report, results: results))

        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertTrue(viewModel.state.reports.first?.isEvaluated == true)
        XCTAssertEqual(viewModel.state.reports.first?.evaluationResults, results)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }

    func testReEvaluateReport_Success() async {
        // Given
        let report = DomainPost(
            goodItems: ["Пункт 1", "Пункт 2"],
            badItems: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true, true]
        )
        let newResults = [false, true]
        
        // Добавляем отчет в состояние
        viewModel.state.reports = [report]

        // When
        await viewModel.handle(.reEvaluateReport(report, results: newResults))

        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertTrue(viewModel.state.reports.first?.isEvaluated == true)
        XCTAssertEqual(viewModel.state.reports.first?.evaluationResults, newResults)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }

    // MARK: - Delete Report Tests

    func testDeleteReport_Success() async {
        // Given
        let report = DomainPost(goodItems: ["Пункт 1"], badItems: [], type: .custom)
        viewModel.state.reports = [report]

        // When
        await viewModel.handle(.deleteReport(report))

        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
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
        viewModel.state.isSelectionMode = true

        // When
        await viewModel.handle(.selectReport(reportId))

        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(reportId))

        // When - deselect
        await viewModel.handle(.selectReport(reportId))

        // Then
        XCTAssertFalse(viewModel.state.selectedReportIDs.contains(reportId))
    }

    func testSelectAllReports() async {
        // Given
        let reports = [
            DomainPost(goodItems: ["Пункт 1"], badItems: [], type: .custom),
            DomainPost(goodItems: ["Пункт 2"], badItems: [], type: .custom)
        ]
        viewModel.state.reports = reports
        viewModel.state.isSelectionMode = true

        // When
        await viewModel.handle(.selectAllReports)

        // Then
        XCTAssertEqual(viewModel.state.selectedReportIDs.count, 2)
        XCTAssertTrue(viewModel.state.allSelected)
    }

    func testDeselectAllReports() async {
        // Given
        let reports = [
            DomainPost(goodItems: ["Пункт 1"], badItems: [], type: .custom),
            DomainPost(goodItems: ["Пункт 2"], badItems: [], type: .custom)
        ]
        viewModel.state.reports = reports
        viewModel.state.isSelectionMode = true
        viewModel.state.selectedReportIDs = Set(reports.map { $0.id })

        // When
        await viewModel.handle(.deselectAllReports)

        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
    }

    func testDeleteSelectedReports() async {
        // Given
        let reports = [
            DomainPost(goodItems: ["Пункт 1"], badItems: [], type: .custom),
            DomainPost(goodItems: ["Пункт 2"], badItems: [], type: .custom)
        ]
        viewModel.state.reports = reports
        viewModel.state.isSelectionMode = true
        viewModel.state.selectedReportIDs = Set(reports.map { $0.id })

        // When
        await viewModel.handle(.deleteSelectedReports)

        // Then
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
        XCTAssertFalse(viewModel.state.isSelectionMode)
    }

    // MARK: - Button States Tests

    func testUpdateButtonStates_CanCreateReport() async {
        // Given - нет активного отчета на сегодня
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldReport = DomainPost(
            date: yesterday,
            goodItems: ["Старый пункт"],
            badItems: [],
            type: .custom,
            isEvaluated: true
        )
        viewModel.state.reports = [oldReport]

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertTrue(viewModel.state.canCreateReport)
        XCTAssertFalse(viewModel.state.canEvaluateReport)
    }

    func testUpdateButtonStates_CannotCreateReport() async {
        // Given - есть активный отчет на сегодня
        let today = Calendar.current.startOfDay(for: Date())
        let activeReport = DomainPost(
            date: today,
            goodItems: ["Активный пункт"],
            badItems: [],
            type: .custom,
            isEvaluated: false
        )
        viewModel.state.reports = [activeReport]

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertFalse(viewModel.state.canCreateReport)
        XCTAssertTrue(viewModel.state.canEvaluateReport)
    }

    func testUpdateButtonStates_CanEvaluateReport() async {
        // Given - есть неоцененный отчет на сегодня
        let today = Calendar.current.startOfDay(for: Date())
        let unevaluatedReport = DomainPost(
            date: today,
            goodItems: ["Неоцененный пункт"],
            badItems: [],
            type: .custom,
            isEvaluated: false
        )
        viewModel.state.reports = [unevaluatedReport]

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertFalse(viewModel.state.canCreateReport)
        XCTAssertTrue(viewModel.state.canEvaluateReport)
    }

    func testUpdateButtonStates_CannotEvaluateReport() async {
        // Given - все отчеты оценены
        let today = Calendar.current.startOfDay(for: Date())
        let evaluatedReport = DomainPost(
            date: today,
            goodItems: ["Оцененный пункт"],
            badItems: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true]
        )
        viewModel.state.reports = [evaluatedReport]

        // When
        await viewModel.handle(.loadReports)

        // Then
        XCTAssertTrue(viewModel.state.canCreateReport)
        XCTAssertFalse(viewModel.state.canEvaluateReport)
    }

    // MARK: - Computed Properties Tests

    func testEvaluableReports() {
        // Given
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let todayUnevaluated = DomainPost(
            date: today,
            goodItems: ["Сегодня неоцененный"],
            badItems: [],
            type: .custom,
            isEvaluated: false
        )
        let todayEvaluated = DomainPost(
            date: today,
            goodItems: ["Сегодня оцененный"],
            badItems: [],
            type: .custom,
            isEvaluated: true
        )
        let yesterdayUnevaluated = DomainPost(
            date: yesterday,
            goodItems: ["Вчера неоцененный"],
            badItems: [],
            type: .custom,
            isEvaluated: false
        )
        
        viewModel.state.reports = [todayUnevaluated, todayEvaluated, yesterdayUnevaluated]

        // When
        let evaluableReports = viewModel.state.evaluableReports

        // Then
        XCTAssertEqual(evaluableReports.count, 1)
        XCTAssertEqual(evaluableReports.first?.goodItems.first, "Сегодня неоцененный")
    }

    func testEvaluatedReports() {
        // Given
        let evaluatedReport = DomainPost(
            goodItems: ["Оцененный"],
            badItems: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true]
        )
        let unevaluatedReport = DomainPost(
            goodItems: ["Неоцененный"],
            badItems: [],
            type: .custom,
            isEvaluated: false
        )
        
        viewModel.state.reports = [evaluatedReport, unevaluatedReport]

        // When
        let evaluatedReports = viewModel.state.evaluatedReports

        // Then
        XCTAssertEqual(evaluatedReports.count, 1)
        XCTAssertEqual(evaluatedReports.first?.goodItems.first, "Оцененный")
    }

    func testClearError() async {
        // Given
        viewModel.state.error = NSError(domain: "test", code: 1)

        // When
        await viewModel.handle(.clearError)

        // Then
        XCTAssertNil(viewModel.state.error)
    }
}

// MARK: - Mock Classes

fileprivate final class MockPostRepository: PostRepositoryProtocol {
    var posts: [DomainPost] = []
    var shouldThrowError = false

    func save(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        posts.append(post)
    }

    func fetch() async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return posts
    }

    func fetch(for date: Date) async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return posts.filter { post in
            post.date >= startOfDay && post.date < endOfDay
        }
    }

    func update(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }

    func delete(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        posts.removeAll { $0.id == post.id }
    }

    func clear() async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        posts.removeAll()
    }
}

fileprivate final class MockSettingsRepository: SettingsRepositoryProtocol {
    var shouldThrowError = false
    private var settings: [String: Any] = [:]

    func saveNotificationSettings(enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        settings["notification"] = (enabled, mode, intervalHours, startHour, endHour)
    }

    func loadNotificationSettings() async throws -> (enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return settings["notification"] as? (Bool, NotificationMode, Int, Int, Int) ?? (false, .hourly, 8, 8, 22)
    }

    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        settings["telegram"] = (token, chatId, botId)
    }

    func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?) {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return settings["telegram"] as? (String?, String?, String?) ?? (nil, nil, nil)
    }

    func saveReportStatus(_ status: ReportStatus) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        settings["reportStatus"] = status
    }

    func loadReportStatus() async throws -> ReportStatus {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return settings["reportStatus"] as? ReportStatus ?? .notStarted
    }

    func saveForceUnlock(_ forceUnlock: Bool) async throws {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        settings["forceUnlock"] = forceUnlock
    }

    func loadForceUnlock() async throws -> Bool {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return settings["forceUnlock"] as? Bool ?? false
    }
} 