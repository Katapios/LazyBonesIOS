import XCTest
@testable import LazyBones

@MainActor
final class MainViewModelNewTests: XCTestCase {
    
    var viewModel: MainViewModelNew!
    fileprivate var mockGetReportsUseCase: MockGetReportsUseCase!
    fileprivate var mockUpdateStatusUseCase: MockUpdateStatusUseCase!
    fileprivate var mockSettingsRepository: MVN_MockSettingsRepository!
    fileprivate var mockTimerService: MockPostTimerService!
    
    override func setUp() {
        super.setUp()
        
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockUpdateStatusUseCase = MockUpdateStatusUseCase()
        mockSettingsRepository = MVN_MockSettingsRepository()
        mockTimerService = MockPostTimerService()
        
        viewModel = MainViewModelNew(
            getReportsUseCase: mockGetReportsUseCase,
            updateStatusUseCase: mockUpdateStatusUseCase,
            settingsRepository: mockSettingsRepository,
            timerService: mockTimerService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockGetReportsUseCase = nil
        mockUpdateStatusUseCase = nil
        mockSettingsRepository = nil
        mockTimerService = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testInitialState() {
        XCTAssertEqual(viewModel.state.reportStatus, .notStarted)
        XCTAssertEqual(viewModel.state.goodCountToday, 0)
        XCTAssertEqual(viewModel.state.badCountToday, 0)
        XCTAssertFalse(viewModel.state.hasReportForToday)
        XCTAssertTrue(viewModel.state.canEditReport)
        XCTAssertEqual(viewModel.state.buttonTitle, "Создать отчёт")
        XCTAssertEqual(viewModel.state.buttonIcon, "plus.circle.fill")
        XCTAssertEqual(viewModel.state.buttonColor, .black)
    }
    
    func testLoadData() async {
        // Given
        let mockReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Хорошее дело 1", "Хорошее дело 2"],
                badItems: ["Плохое дело 1"],
                published: true,
                voiceNotes: [],
                type: .regular
            )
        ]
        
        mockGetReportsUseCase.mockReports = mockReports
        mockSettingsRepository.mockNotificationSettings = (true, .hourly, 8, 8, 22)
        mockSettingsRepository.mockReportStatus = .sent
        
        // When
        await viewModel.handle(.loadData)
        
        // Then
        XCTAssertEqual(viewModel.state.goodCountToday, 2)
        XCTAssertEqual(viewModel.state.badCountToday, 1)
        XCTAssertTrue(viewModel.state.hasReportForToday)
        XCTAssertEqual(viewModel.state.reportStatus, .sent)
        XCTAssertEqual(viewModel.state.notificationStartHour, 8)
        XCTAssertEqual(viewModel.state.notificationEndHour, 22)
    }
    
    func testUpdateStatus() async {
        // Given
        mockUpdateStatusUseCase.mockReportStatus = .inProgress
        
        // When
        await viewModel.handle(.updateStatus)
        
        // Then
        XCTAssertEqual(viewModel.state.reportStatus, .inProgress)
        XCTAssertTrue(viewModel.state.canEditReport)
    }
    
    func testCheckForNewDay() async {
        // Given
        mockUpdateStatusUseCase.mockReportStatus = .notStarted
        
        // When
        await viewModel.handle(.checkForNewDay)
        
        // Then
        XCTAssertEqual(viewModel.state.reportStatus, .notStarted)
        XCTAssertTrue(viewModel.state.canEditReport)
    }
    
    func testUpdateTime() async {
        // Given
        mockTimerService.mockTimeLeft = "До конца: 02:30:15"
        mockTimerService.mockTimeProgress = 0.75
        
        // When
        await viewModel.handle(.updateTime)
        
        // Then
        XCTAssertEqual(viewModel.state.timeLeft, "До конца: 02:30:15")
        XCTAssertEqual(viewModel.state.timeProgress, 0.75)
        XCTAssertEqual(viewModel.state.timerTimeTextOnly, "02:30:15")
    }

    // MARK: - Timer label logic
    func testTimerLabel_DuringPeriod_UsesDoKoncza() async {
        // Given
        mockTimerService.mockTimeLeft = "До конца: 00:10:00"
        mockTimerService.mockTimeProgress = 0.2
        mockSettingsRepository.mockReportStatus = .inProgress
        await viewModel.handle(.loadData)

        // When
        await viewModel.handle(.updateTime)

        // Then
        XCTAssertEqual(viewModel.state.timerLabel, "До конца")
        XCTAssertEqual(viewModel.state.timeLeft, "До конца: 00:10:00")
        XCTAssertEqual(viewModel.state.timeProgress, 0.2, accuracy: 1e-6)
    }

    func testTimerLabel_BeforeStart_UsesDoStarta() async {
        // Given
        mockTimerService.mockTimeLeft = "До старта: 01:00:00"
        mockTimerService.mockTimeProgress = 0.0
        mockSettingsRepository.mockReportStatus = .notStarted
        await viewModel.handle(.loadData)

        // When
        await viewModel.handle(.updateTime)

        // Then
        XCTAssertEqual(viewModel.state.timerLabel, "До старта")
        XCTAssertEqual(viewModel.state.timeLeft, "До старта: 01:00:00")
        XCTAssertEqual(viewModel.state.timeProgress, 0.0, accuracy: 1e-6)
    }

    func testTimerLabel_SentStatus_ForcesDoStartaAndZeroProgress() async {
        // Given
        mockTimerService.mockTimeLeft = "До конца: 00:05:00"
        mockTimerService.mockTimeProgress = 0.9
        mockSettingsRepository.mockReportStatus = .sent

        // When: загрузим статус + обновим время
        await viewModel.handle(.loadData)
        await viewModel.handle(.updateTime)

        // Then: даже если сервис говорит "До конца", VM должна показать "До старта" и прогресс 0
        XCTAssertEqual(viewModel.state.reportStatus, .sent)
        XCTAssertEqual(viewModel.state.timerLabel, "До старта")
        XCTAssertEqual(viewModel.state.timeProgress, 0.0, accuracy: 1e-6)
    }

    func testDayChange_FromSent_ResetsToBeforeStart() async {
        // Given: изначально день завершен (sent)
        mockSettingsRepository.mockReportStatus = .sent
        mockTimerService.mockTimeLeft = "До конца: 00:05:00"
        mockTimerService.mockTimeProgress = 0.9
        await viewModel.handle(.loadData)
        await viewModel.handle(.updateTime)
        XCTAssertEqual(viewModel.state.reportStatus, .sent)
        XCTAssertEqual(viewModel.state.timerLabel, "До старта")
        XCTAssertEqual(viewModel.state.timeProgress, 0.0, accuracy: 1e-6)

        // Когда наступил новый день — use case возвращает notStarted
        mockUpdateStatusUseCase.mockReportStatus = .notStarted
        // И сервис таймера теперь в состоянии "до старта"
        mockTimerService.mockTimeLeft = "До старта: 10:00:00"
        mockTimerService.mockTimeProgress = 0.0

        // When: обрабатываем смену дня и обновление времени
        await viewModel.handle(.checkForNewDay)
        await viewModel.handle(.updateTime)

        // Then: статус сброшен, метка до старта, прогресс 0
        XCTAssertEqual(viewModel.state.reportStatus, .notStarted)
        XCTAssertEqual(viewModel.state.timerLabel, "До старта")
        XCTAssertEqual(viewModel.state.timeLeft, "До старта: 10:00:00")
        XCTAssertEqual(viewModel.state.timeProgress, 0.0, accuracy: 1e-6)
        XCTAssertEqual(viewModel.state.timerTimeTextOnly, "10:00:00")
    }
    
    func testClearError() async {
        // Given
        viewModel.state.error = NSError(domain: "test", code: 1)
        
        // When
        await viewModel.handle(.clearError)
        
        // Then
        XCTAssertNil(viewModel.state.error)
    }
    
    func testButtonStateWhenReportExists() async {
        // Given
        let mockReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: ["Хорошее дело"],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .regular
            )
        ]
        
        mockGetReportsUseCase.mockReports = mockReports
        mockSettingsRepository.mockReportStatus = .inProgress
        
        // When
        await viewModel.handle(.loadData)
        
        // Then
        XCTAssertTrue(viewModel.state.hasReportForToday)
        XCTAssertEqual(viewModel.state.buttonTitle, "Редактировать отчёт")
        XCTAssertEqual(viewModel.state.buttonIcon, "pencil.circle.fill")
        XCTAssertEqual(viewModel.state.buttonColor, .black)
    }
    
    func testButtonStateWhenReportSent() async {
        // Given
        mockSettingsRepository.mockReportStatus = .sent
        
        // When
        await viewModel.handle(.loadData)
        
        // Then
        XCTAssertFalse(viewModel.state.hasReportForToday)
        XCTAssertEqual(viewModel.state.buttonTitle, "Создать отчёт")
        XCTAssertEqual(viewModel.state.buttonIcon, "plus.circle.fill")
        XCTAssertEqual(viewModel.state.buttonColor, .gray)
        XCTAssertFalse(viewModel.state.canEditReport)
    }
    
    func testCalculateProgressCountsWithCustomReport() async {
        // Given
        let mockReports = [
            DomainPost(
                id: UUID(),
                date: Date(),
                goodItems: [],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .custom,
                isEvaluated: true,
                evaluationResults: [true, false, true, false, true] // 3 хороших, 2 плохих
            )
        ]
        
        mockGetReportsUseCase.mockReports = mockReports
        
        // When
        await viewModel.handle(.loadData)
        
        // Then
        XCTAssertEqual(viewModel.state.goodCountToday, 3)
        XCTAssertEqual(viewModel.state.badCountToday, 2)
    }
    
    func testCalculateProgressCountsWithMultipleReports() async {
        // Given
        let today = Date()
        let mockReports = [
            DomainPost(
                id: UUID(),
                date: today,
                goodItems: ["Хорошее 1", "Хорошее 2"],
                badItems: ["Плохое 1"],
                published: true,
                voiceNotes: [],
                type: .regular
            ),
            DomainPost(
                id: UUID(),
                date: today,
                goodItems: [],
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .custom,
                isEvaluated: true,
                evaluationResults: [true, false, true] // 2 хороших, 1 плохой
            )
        ]
        
        mockGetReportsUseCase.mockReports = mockReports
        
        // When
        await viewModel.handle(.loadData)
        
        // Then
        XCTAssertEqual(viewModel.state.goodCountToday, 4) // 2 из regular + 2 из custom
        XCTAssertEqual(viewModel.state.badCountToday, 2) // 1 из regular + 1 из custom
    }
}

// MARK: - Mock Classes

fileprivate final class MVN_MockSettingsRepository: SettingsRepositoryProtocol {
    var mockNotificationSettings: (Bool, NotificationMode, Int, Int, Int)?
    var mockReportStatus: ReportStatus = .notStarted

    func saveNotificationSettings(enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) async throws {}
    func loadNotificationSettings() async throws -> (enabled: Bool, mode: NotificationMode, intervalHours: Int, startHour: Int, endHour: Int) {
        if let v = mockNotificationSettings { return (v.0, v.1, v.2, v.3, v.4) }
        return (false, .hourly, 8, 8, 22)
    }
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws {}
    func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?) { (nil, nil, nil) }
    func saveReportStatus(_ status: ReportStatus) async throws { mockReportStatus = status }
    func loadReportStatus() async throws -> ReportStatus { mockReportStatus }
    func saveForceUnlock(_ forceUnlock: Bool) async throws {}
    func loadForceUnlock() async throws -> Bool { false }
}

fileprivate final class MockGetReportsUseCase: GetReportsUseCaseProtocol {
    var mockReports: [DomainPost] = []
    var shouldThrowError = false
    
    func execute(input: GetReportsInput) async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return mockReports
    }
}

fileprivate final class MockUpdateStatusUseCase: UpdateStatusUseCaseProtocol {
    var mockReportStatus: ReportStatus = .notStarted
    var shouldThrowError = false
    
    func execute(input: UpdateStatusInput) async throws -> ReportStatus {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return mockReportStatus
    }
}

fileprivate final class MockPostTimerService: PostTimerServiceProtocol {
    var mockTimeLeft: String = ""
    var mockTimeProgress: Double = 0.0
    
    func startTimer() {}
    func stopTimer() {}
    func updateTimeLeft() {}
    func updateReportStatus(_ status: ReportStatus) {}
    
    var timeLeft: String { mockTimeLeft }
    var timeProgress: Double { mockTimeProgress }
} 