import XCTest
@testable import LazyBones

@MainActor
final class MainViewModelNewTests: XCTestCase {
    
    var viewModel: MainViewModelNew!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockUpdateStatusUseCase: MockUpdateStatusUseCase!
    var mockSettingsRepository: MockSettingsRepository!
    var mockTimerService: MockPostTimerService!
    
    override func setUp() {
        super.setUp()
        
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockUpdateStatusUseCase = MockUpdateStatusUseCase()
        mockSettingsRepository = MockSettingsRepository()
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
        mockSettingsRepository.mockNotificationSettings = (true, .daily, 8, 8, 22)
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

class MockGetReportsUseCase: GetReportsUseCaseProtocol {
    var mockReports: [DomainPost] = []
    var shouldThrowError = false
    
    func execute(input: GetReportsInput) async throws -> [DomainPost] {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return mockReports
    }
}

class MockUpdateStatusUseCase: UpdateStatusUseCaseProtocol {
    var mockReportStatus: ReportStatus = .notStarted
    var shouldThrowError = false
    
    func execute(input: UpdateStatusInput) async throws -> ReportStatus {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
        return mockReportStatus
    }
}

class MockPostTimerService: PostTimerServiceProtocol {
    var mockTimeLeft: String = ""
    var mockTimeProgress: Double = 0.0
    
    func startTimer() {}
    func stopTimer() {}
    func updateTimeLeft() {}
    func updateReportStatus(_ status: ReportStatus) {}
    
    var timeLeft: String { mockTimeLeft }
    var timeProgress: Double { mockTimeProgress }
} 