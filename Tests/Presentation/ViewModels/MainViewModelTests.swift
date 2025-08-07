import XCTest
@testable import LazyBones

@MainActor
class MainViewModelTests: XCTestCase {
    
    var viewModel: MainViewModel!
    var mockStore: PostStore!
    
    override func setUp() {
        super.setUp()
        mockStore = PostStore()
        viewModel = MainViewModel(store: mockStore)
    }
    
    override func tearDown() {
        viewModel.timer?.invalidate()
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_SetsUpTimer() {
        // Given & When - в setUp()
        
        // Then
        XCTAssertNotNil(viewModel.timer)
        XCTAssertTrue(viewModel.timer?.isValid == true)
    }
    
    func testDeinit_InvalidatesTimer() {
        // Given
        let timer = viewModel.timer
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertFalse(timer?.isValid == true)
    }
    
    // MARK: - Report Status Tests
    
    func testReportStatus_DelegatesToStore() {
        // Given
        mockStore.reportStatus = .inProgress
        
        // When & Then
        XCTAssertEqual(viewModel.reportStatus, .inProgress)
    }
    
    func testReportStatusText_ReturnsCorrectText() {
        // Given
        let testCases: [(ReportStatus, String)] = [
            
            (.inProgress, "Отчет заполняется..."),
            (.notStarted, "Заполни отчет!"),
            (.notCreated, "Отчёт не создан"),
            (.notSent, "Отчёт не отправлен"),
            (.sent, "Отчет отправлен")
        ]
        
        for (status, expectedText) in testCases {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertEqual(viewModel.reportStatusText, expectedText, "Failed for status: \(status)")
        }
    }
    
    func testReportStatusColor_ReturnsCorrectColor() {
        // Given
        let blackStatuses: [ReportStatus] = [.inProgress, .sent]
        let grayStatuses: [ReportStatus] = [.notStarted, .notCreated, .notSent]
        
        for status in blackStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertEqual(viewModel.reportStatusColor, .black, "Failed for status: \(status)")
        }
        
        for status in grayStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertEqual(viewModel.reportStatusColor, .gray, "Failed for status: \(status)")
        }
    }
    
    // MARK: - Today's Report Tests
    
    func testPostForToday_ReturnsTodayReport() {
        // Given
        let today = Date()
        let todayPost = Post(id: UUID(), date: today, goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [todayPost]
        
        // When & Then
        XCTAssertEqual(viewModel.postForToday?.id, todayPost.id)
    }
    
    func testPostForToday_ReturnsNilWhenNoTodayReport() {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayPost = Post(id: UUID(), date: yesterday, goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [yesterdayPost]
        
        // When & Then
        XCTAssertNil(viewModel.postForToday)
    }
    
    func testHasReportForToday_ReturnsTrueWhenReportExists() {
        // Given
        let today = Date()
        let todayPost = Post(id: UUID(), date: today, goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [todayPost]
        
        // When & Then
        XCTAssertTrue(viewModel.hasReportForToday)
    }
    
    func testHasReportForToday_ReturnsFalseWhenNoReport() {
        // Given
        mockStore.posts = []
        
        // When & Then
        XCTAssertFalse(viewModel.hasReportForToday)
    }
    
    func testCanEditReport_ReturnsTrueForEditableStatuses() {
        // Given
        let editableStatuses: [ReportStatus] = [.notStarted, .inProgress]
        
        for status in editableStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertTrue(viewModel.canEditReport, "Failed for status: \(status)")
        }
    }
    
    func testCanEditReport_ReturnsFalseForNonEditableStatuses() {
        // Given
        let nonEditableStatuses: [ReportStatus] = [.notCreated, .notSent, .sent]
        
        for status in nonEditableStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertFalse(viewModel.canEditReport, "Failed for status: \(status)")
        }
    }
    
    // MARK: - Button Configuration Tests
    
    func testButtonTitle_ReturnsEditWhenReportExists() {
        // Given
        let today = Date()
        let todayPost = Post(id: UUID(), date: today, goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [todayPost]
        
        // When & Then
        XCTAssertEqual(viewModel.buttonTitle, "Редактировать отчёт")
    }
    
    func testButtonTitle_ReturnsCreateWhenNoReport() {
        // Given
        mockStore.posts = []
        
        // When & Then
        XCTAssertEqual(viewModel.buttonTitle, "Создать отчёт")
    }
    
    func testButtonIcon_ReturnsEditIconWhenReportExists() {
        // Given
        let today = Date()
        let todayPost = Post(id: UUID(), date: today, goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [todayPost]
        
        // When & Then
        XCTAssertEqual(viewModel.buttonIcon, "pencil.circle.fill")
    }
    
    func testButtonIcon_ReturnsCreateIconWhenNoReport() {
        // Given
        mockStore.posts = []
        
        // When & Then
        XCTAssertEqual(viewModel.buttonIcon, "plus.circle.fill")
    }
    
    func testButtonColor_ReturnsGrayForCompletedStatuses() {
        // Given
        let grayStatuses: [ReportStatus] = [.sent, .notCreated, .notSent]
        
        for status in grayStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertEqual(viewModel.buttonColor, .gray, "Failed for status: \(status)")
        }
    }
    
    func testButtonColor_ReturnsBlackForActiveStatuses() {
        // Given
        let blackStatuses: [ReportStatus] = [.inProgress, .notStarted]
        
        for status in blackStatuses {
            // When
            mockStore.reportStatus = status
            
            // Then
            XCTAssertEqual(viewModel.buttonColor, .black, "Failed for status: \(status)")
        }
    }
    
    // MARK: - Progress Counters Tests (учитывает разные типы отчетов)
    
    func testGoodCountToday_CountsRegularReport() {
        // Given
        let today = Date()
        let regularPost = Post(id: UUID(), date: today, goodItems: ["Good1", "Good2", ""], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [regularPost]
        
        // When & Then
        XCTAssertEqual(viewModel.goodCountToday, 2) // Пустые строки не считаются
    }
    
    func testGoodCountToday_CountsCustomEvaluatedReport() {
        // Given
        let today = Date()
        let customPost = Post(id: UUID(), date: today, goodItems: ["Item1", "Item2"], badItems: [], published: false, voiceNotes: [], type: .custom, isEvaluated: true, evaluationResults: [true, false, true])
        mockStore.posts = [customPost]
        
        // When & Then
        XCTAssertEqual(viewModel.goodCountToday, 2) // Только true результаты
    }
    
    func testGoodCountToday_IgnoresCustomNonEvaluatedReport() {
        // Given
        let today = Date()
        let customPost = Post(id: UUID(), date: today, goodItems: ["Item1", "Item2"], badItems: [], published: false, voiceNotes: [], type: .custom, isEvaluated: false)
        mockStore.posts = [customPost]
        
        // When & Then
        XCTAssertEqual(viewModel.goodCountToday, 0)
    }
    
    func testBadCountToday_CountsRegularReport() {
        // Given
        let today = Date()
        let regularPost = Post(id: UUID(), date: today, goodItems: [], badItems: ["Bad1", "Bad2", ""], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [regularPost]
        
        // When & Then
        XCTAssertEqual(viewModel.badCountToday, 2) // Пустые строки не считаются
    }
    
    func testBadCountToday_CountsCustomEvaluatedReport() {
        // Given
        let today = Date()
        let customPost = Post(id: UUID(), date: today, goodItems: ["Item1", "Item2"], badItems: [], published: false, voiceNotes: [], type: .custom, isEvaluated: true, evaluationResults: [true, false, true])
        mockStore.posts = [customPost]
        
        // When & Then
        XCTAssertEqual(viewModel.badCountToday, 1) // Только false результаты
    }
    
    func testBadCountToday_IgnoresCustomNonEvaluatedReport() {
        // Given
        let today = Date()
        let customPost = Post(id: UUID(), date: today, goodItems: [], badItems: ["Bad1", "Bad2"], published: false, voiceNotes: [], type: .custom, isEvaluated: false)
        mockStore.posts = [customPost]
        
        // When & Then
        XCTAssertEqual(viewModel.badCountToday, 0)
    }
    
    // MARK: - Timer Tests
    
    func testTimeLeft_DelegatesToStore() {
        // Given
        mockStore.timeLeft = "Test Time"
        
        // When & Then
        XCTAssertEqual(viewModel.timeLeft, "Test Time")
    }
    
    func testTimerTimeTextOnly_ExtractsTimeFromStore() {
        // Given
        mockStore.timeLeft = "До конца: 02:30:15"
        
        // When & Then
        XCTAssertEqual(viewModel.timerTimeTextOnly, "02:30:15")
    }
    
    func testTimerTimeTextOnly_ReturnsFullStringWhenNoColon() {
        // Given
        mockStore.timeLeft = "No colon here"
        
        // When & Then
        XCTAssertEqual(viewModel.timerTimeTextOnly, "No colon here")
    }
    
    // MARK: - Tag Management Tests
    
    func testGoodTags_DelegatesToStore() {
        // Given
        mockStore.goodTags = ["Tag1", "Tag2"]
        
        // When & Then
        XCTAssertEqual(viewModel.goodTags, ["Tag1", "Tag2"])
    }
    
    func testBadTags_DelegatesToStore() {
        // Given
        mockStore.badTags = ["BadTag1", "BadTag2"]
        
        // When & Then
        XCTAssertEqual(viewModel.badTags, ["BadTag1", "BadTag2"])
    }
    
    // MARK: - Background Task Management Tests
    
    func testNotificationHours_DelegatesToStore() {
        // Given
        mockStore.notificationStartHour = 9
        mockStore.notificationEndHour = 18
        
        // When & Then
        XCTAssertEqual(viewModel.notificationStartHour, 9)
        XCTAssertEqual(viewModel.notificationEndHour, 18)
    }
    
    func testCurrentDay_DelegatesToStore() {
        // Given
        let testDate = Date()
        mockStore.currentDay = testDate
        
        // When & Then
        XCTAssertEqual(viewModel.currentDay, testDate)
    }
    
    // MARK: - Actions Tests
    
    func testCheckForNewDay_DelegatesToStore() {
        // Given
        var checkCalled = false
        mockStore.checkForNewDay = {
            checkCalled = true
        }
        
        // When
        viewModel.checkForNewDay()
        
        // Then
        XCTAssertTrue(checkCalled)
    }
} 