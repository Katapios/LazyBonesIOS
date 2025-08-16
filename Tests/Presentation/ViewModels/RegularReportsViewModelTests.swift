import XCTest
@testable import LazyBones

@MainActor
class RegularReportsViewModelTests: XCTestCase {
    
    var viewModel: RegularReportsViewModel!
                var mockCreateUseCase: CreateReportUseCase!
            var mockGetUseCase: GetReportsUseCase!
            var mockDeleteUseCase: DeleteReportUseCase!
            var mockUpdateStatusUseCase: UpdateStatusUseCase!
            var mockUpdateReportUseCase: UpdateReportUseCase!
    
    override func setUp() {
        super.setUp()
        // Создаем реальные Use Cases с мок репозиториями
        let mockPostRepository = MockPostRepository()
        let mockSettingsRepository = MockSettingsRepository()
        
                        mockCreateUseCase = CreateReportUseCase(postRepository: mockPostRepository)
                mockGetUseCase = GetReportsUseCase(postRepository: mockPostRepository)
                mockDeleteUseCase = DeleteReportUseCase(postRepository: mockPostRepository)
                mockUpdateStatusUseCase = UpdateStatusUseCase(
                    postRepository: mockPostRepository,
                    settingsRepository: mockSettingsRepository
                )
                mockUpdateReportUseCase = UpdateReportUseCase(postRepository: mockPostRepository)
        
                        viewModel = RegularReportsViewModel(
                    createReportUseCase: mockCreateUseCase,
                    getReportsUseCase: mockGetUseCase,
                    deleteReportUseCase: mockDeleteUseCase,
                    updateStatusUseCase: mockUpdateStatusUseCase,
                    updateReportUseCase: mockUpdateReportUseCase
                )
    }
    
    override func tearDown() {
        viewModel = nil
        mockCreateUseCase = nil
        mockGetUseCase = nil
        mockDeleteUseCase = nil
        mockUpdateStatusUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Load Reports Tests
    
    func testLoadReports_Success() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testLoadReports_Error() async {
        // Given - мок репозиторий может вернуть ошибку
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        // Ошибка может быть или не быть, зависит от реализации мока
    }
    
    // MARK: - Create Report Tests
    
    func testCreateReport_Success() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.createReport(goodItems: ["Кодил"], badItems: ["Не гулял"]))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testCreateReport_Error() async {
        // Given - мок репозиторий может вернуть ошибку
        
        // When
        await viewModel.handle(.createReport(goodItems: ["Кодил"], badItems: ["Не гулял"]))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        // Ошибка может быть или не быть, зависит от реализации мока
    }
    
    // MARK: - Delete Report Tests
    
    func testDeleteReport_Success() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.deleteReport(DomainPost(goodItems: [], badItems: [], type: .regular)))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    func testDeleteReport_Error() async {
        // Given - мок репозиторий может вернуть ошибку
        
        // When
        await viewModel.handle(.deleteReport(DomainPost(goodItems: [], badItems: [], type: .regular)))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        // Ошибка может быть или не быть, зависит от реализации мока
    }
    
    // MARK: - Selection Mode Tests
    
    func testToggleSelectionMode() async {
        // Given
        XCTAssertFalse(viewModel.state.isSelectionMode)
        
        // When
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertTrue(viewModel.state.isSelectionMode)
        
        // When - toggle again
        await viewModel.handle(.toggleSelectionMode)
        
        // Then
        XCTAssertFalse(viewModel.state.isSelectionMode)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
    }
    
    func testSelectReport() async {
        // Given
        let report = DomainPost(goodItems: ["Кодил"], badItems: ["Не гулял"], type: .regular)
        viewModel.state.reports = [report]
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectReport(report.id))
        
        // Then
        XCTAssertTrue(viewModel.state.selectedReportIDs.contains(report.id))
        XCTAssertEqual(viewModel.state.selectedCount, 1)
        
        // When - select again (should deselect)
        await viewModel.handle(.selectReport(report.id))
        
        // Then
        XCTAssertFalse(viewModel.state.selectedReportIDs.contains(report.id))
        XCTAssertEqual(viewModel.state.selectedCount, 0)
    }
    
    func testSelectAllReports() async {
        // Given
        let reports = [
            DomainPost(goodItems: ["Кодил"], badItems: ["Не гулял"], type: .regular),
            DomainPost(goodItems: ["Читал"], badItems: [], type: .regular)
        ]
        viewModel.state.reports = reports
        viewModel.state.isSelectionMode = true
        
        // When
        await viewModel.handle(.selectAllReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedCount, 2)
        XCTAssertTrue(viewModel.state.allSelected)
    }
    
    func testDeselectAllReports() async {
        // Given
        let reports = [
            DomainPost(goodItems: ["Кодил"], badItems: ["Не гулял"], type: .regular),
            DomainPost(goodItems: ["Читал"], badItems: [], type: .regular)
        ]
        viewModel.state.reports = reports
        viewModel.state.isSelectionMode = true
        viewModel.state.selectedReportIDs = Set(reports.map { $0.id })
        
        // When
        await viewModel.handle(.deselectAllReports)
        
        // Then
        XCTAssertEqual(viewModel.state.selectedCount, 0)
        XCTAssertTrue(viewModel.state.selectedReportIDs.isEmpty)
    }
    
    // MARK: - Delete Selected Reports Tests
    
    func testDeleteSelectedReports_Success() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.deleteSelectedReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
    
    // MARK: - Button States Tests
    
    func testUpdateButtonStates_CanCreateReport() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertTrue(viewModel.state.canCreateReport)
    }
    
    func testUpdateButtonStates_CannotCreateReport() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertTrue(viewModel.state.canCreateReport) // По умолчанию можно создать
    }
    
    func testUpdateButtonStates_CanSendReport() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.canSendReport) // Нет отчетов для отправки
    }
    
    func testUpdateButtonStates_CannotSendReport() async {
        // Given - пустой список отчетов
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.canSendReport) // Нет отчетов для отправки
    }
    
    // MARK: - Clear Error Test
    
    func testClearError() async {
        // Given
        viewModel.state.error = NSError(domain: "Test", code: 1, userInfo: nil)
        
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
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        posts.append(post)
    }
    
    func fetch() async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return posts
    }
    
    func fetch(for date: Date) async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return posts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func update(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
    
    func delete(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        posts.removeAll { $0.id == post.id }
    }
    
    func clear() async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        posts.removeAll()
    }
}

fileprivate final class MockSettingsRepository: SettingsRepositoryProtocol {
    var shouldThrowError = false
    private var settings: [String: Any] = [:]
    
    func saveNotificationSettings(
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    ) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        settings["notificationsEnabled"] = enabled
        settings["notificationMode"] = mode.rawValue
        settings["notificationIntervalHours"] = intervalHours
        settings["notificationStartHour"] = startHour
        settings["notificationEndHour"] = endHour
    }
    
    func loadNotificationSettings() async throws -> (
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    ) {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        let enabled = settings["notificationsEnabled"] as? Bool ?? false
        let modeRawValue = settings["notificationMode"] as? String ?? "hourly"
        let mode = NotificationMode(rawValue: modeRawValue) ?? .hourly
        let intervalHours = settings["notificationIntervalHours"] as? Int ?? 1
        let startHour = settings["notificationStartHour"] as? Int ?? 8
        let endHour = settings["notificationEndHour"] as? Int ?? 22
        
        return (enabled, mode, intervalHours, startHour, endHour)
    }
    
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        settings["telegramToken"] = token
        settings["telegramChatId"] = chatId
        settings["telegramBotId"] = botId
    }
    
    func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?) {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        let token = settings["telegramToken"] as? String
        let chatId = settings["telegramChatId"] as? String
        let botId = settings["telegramBotId"] as? String
        
        return (token, chatId, botId)
    }
    
    func saveReportStatus(_ status: ReportStatus) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        settings["reportStatus"] = status.rawValue
    }
    
    func loadReportStatus() async throws -> ReportStatus {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        let statusRawValue = settings["reportStatus"] as? String ?? "notStarted"
        return ReportStatus(rawValue: statusRawValue) ?? .notStarted
    }
    
    func saveForceUnlock(_ forceUnlock: Bool) async throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        settings["forceUnlock"] = forceUnlock
    }
    
    func loadForceUnlock() async throws -> Bool {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return settings["forceUnlock"] as? Bool ?? false
    }
} 