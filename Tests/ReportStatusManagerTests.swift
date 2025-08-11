import XCTest
@testable import LazyBones

class ReportStatusManagerTests: XCTestCase {
    
    var statusManager: ReportStatusManager!
    var mockLocalService: MockLocalReportService!
    var mockTimerService: MockPostTimerService!
    var mockNotificationService: MockPostNotificationService!
    var mockPostsProvider: MockPostsProvider!
    var mockFactory: MockReportStatusFactory!
    
    override func setUp() {
        super.setUp()
        
        mockLocalService = MockLocalReportService()
        mockTimerService = MockPostTimerService()
        mockNotificationService = MockPostNotificationService()
        mockPostsProvider = MockPostsProvider()
        mockFactory = MockReportStatusFactory()
        
        statusManager = ReportStatusManager(
            localService: mockLocalService,
            timerService: mockTimerService,
            notificationService: mockNotificationService,
            postsProvider: mockPostsProvider,
            factory: mockFactory
        )
    }
    
    override func tearDown() {
        statusManager = nil
        mockLocalService = nil
        mockTimerService = nil
        mockNotificationService = nil
        mockPostsProvider = nil
        mockFactory = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testInitialStatus() {
        XCTAssertEqual(statusManager.reportStatus, .notStarted)
        XCTAssertFalse(statusManager.forceUnlock)
    }
    
    func testUpdateStatusWithNoReports() {
        mockPostsProvider.posts = []
        mockFactory.isPeriodActive = true
        
        statusManager.updateStatus()
        
        XCTAssertEqual(statusManager.reportStatus, .notStarted)
        XCTAssertTrue(mockTimerService.updateReportStatusCalled)
        XCTAssertEqual(mockTimerService.lastStatus, .notStarted)
    }
    
    func testUpdateStatusWithUnpublishedReport() {
        let post = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Test"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        mockPostsProvider.posts = [post]
        mockFactory.isPeriodActive = true
        
        statusManager.updateStatus()
        
        XCTAssertEqual(statusManager.reportStatus, .inProgress)
    }
    
    func testUpdateStatusWithPublishedReport() {
        let post = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Test"],
            badItems: [],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        mockPostsProvider.posts = [post]
        mockFactory.isPeriodActive = true
        
        statusManager.updateStatus()
        
        XCTAssertEqual(statusManager.reportStatus, .sent)
    }
    
    func testForceUnlock() {
        statusManager.forceUnlock = true
        
        statusManager.updateStatus()
        
        XCTAssertEqual(statusManager.reportStatus, .notStarted)
    }
    
    func testCheckForNewDay() {
        // Устанавливаем вчерашний день
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        statusManager.currentDay = yesterday
        
        statusManager.checkForNewDay()
        
        // Проверяем, что currentDay обновился
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(statusManager.currentDay, today)
    }

    func testUnlockReportsAfterPublishedReport_StatusNotStartedAndPostKept() {
        // Given: есть опубликованный регулярный отчет за сегодня
        let post = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Good"],
            badItems: ["Bad"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        mockPostsProvider.posts = [post]

        // When: выполняем разблокировку через менеджер
        statusManager.unlockReportCreation()

        // Then: статус сбрасывается на notStarted, пост НЕ удалён, но published снят
        XCTAssertEqual(statusManager.reportStatus, .notStarted)
        XCTAssertEqual(mockPostsProvider.posts.count, 1)
        XCTAssertFalse(mockPostsProvider.posts[0].published)
        // и флаг forceUnlock сохранён в локальном сервисе (одноразовая разблокировка)
        XCTAssertTrue(mockLocalService.savedForceUnlock)
    }
}

// MARK: - Mock Classes

class MockLocalReportService: LocalReportService {
    var savedStatus: ReportStatus = .notStarted
    var savedForceUnlock: Bool = false
    
    override func getReportStatus() -> ReportStatus {
        return savedStatus
    }
    
    override func saveReportStatus(_ status: ReportStatus) {
        savedStatus = status
    }
    
    override func getForceUnlock() -> Bool {
        return savedForceUnlock
    }
    
    override func saveForceUnlock(_ value: Bool) {
        savedForceUnlock = value
    }
}

class MockPostTimerService: PostTimerServiceProtocol {
    var updateReportStatusCalled = false
    var lastStatus: ReportStatus?
    
    func updateReportStatus(_ status: ReportStatus) {
        updateReportStatusCalled = true
        lastStatus = status
    }
    
    func updateTimeLeft() {}
    func startTimer() {}
    func stopTimer() {}
}

class MockPostNotificationService: PostNotificationServiceProtocol {
    var scheduleNotificationsCalled = false
    
    func scheduleNotifications() {
        scheduleNotificationsCalled = true
    }
    
    func cancelAllNotifications() {}
    func cancelNotification(identifier: String) {}
    func getPendingNotifications() async -> [UNNotificationRequest] { return [] }
    func getDeliveredNotifications() async -> [UNNotification] { return [] }
    func scheduleNotificationsIfNeeded() {
        scheduleNotificationsCalled = true
    }
}

class MockPostsProvider: PostsProviderProtocol {
    var posts: [Post] = []
    
    func getPosts() -> [Post] {
        return posts
    }
    
    func updatePosts(_ posts: [Post]) {
        self.posts = posts
    }
}

class MockReportStatusFactory: ReportStatusFactory {
    var isPeriodActive: Bool = true
    
    override func isReportPeriodActive() -> Bool {
        return isPeriodActive
    }
    
    override func createStatus(
        hasRegularReport: Bool,
        isReportPublished: Bool,
        isPeriodActive: Bool,
        forceUnlock: Bool = false
    ) -> ReportStatus {
        if forceUnlock {
            return .notStarted
        }
        
        if hasRegularReport {
            if isPeriodActive {
                return isReportPublished ? .sent : .inProgress
            } else {
                return isReportPublished ? .sent : .notSent
            }
        } else {
            return isPeriodActive ? .notStarted : .notCreated
        }
    }
} 