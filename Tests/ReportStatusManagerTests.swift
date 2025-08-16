import XCTest
@testable import LazyBones

class ReportStatusManagerTests: XCTestCase {
    
    var statusManager: ReportStatusManager!
    var localService: LocalReportService!
    fileprivate var mockTimerService: MockPostTimerService!
    fileprivate var mockNotificationService: MockPostNotificationService!
    fileprivate var mockPostsProvider: MockPostsProvider!
    fileprivate var mockFactory: MockReportStatusFactory!
    
    override func setUp() {
        super.setUp()
        
        localService = LocalReportService.shared
        // Сброс состояния, чтобы тесты были детерминированными
        localService.saveForceUnlock(false)
        localService.saveReportStatus(.notStarted)
        mockTimerService = MockPostTimerService()
        mockNotificationService = MockPostNotificationService()
        mockPostsProvider = MockPostsProvider()
        mockFactory = MockReportStatusFactory()
        
        statusManager = ReportStatusManager(
            localService: localService,
            timerService: mockTimerService,
            notificationService: mockNotificationService,
            postsProvider: mockPostsProvider,
            factory: mockFactory
        )
    }
    
    override func tearDown() {
        // Возврат к базовому состоянию
        LocalReportService.shared.saveForceUnlock(false)
        LocalReportService.shared.saveReportStatus(.notStarted)
        statusManager = nil
        localService = nil
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
}

// MARK: - Mock Classes

// Удалён mock LocalReportService: базовый класс имеет private init, используем LocalReportService.shared

fileprivate final class MockPostTimerService: PostTimerServiceProtocol {
    var updateReportStatusCalled = false
    var lastStatus: ReportStatus?
    var timeLeft: String { "" }
    var timeProgress: Double { 0.0 }
    
    func updateReportStatus(_ status: ReportStatus) {
        updateReportStatusCalled = true
        lastStatus = status
    }
    
    func updateTimeLeft() {}
    func startTimer() {}
    func stopTimer() {}
}

fileprivate final class MockPostNotificationService: PostNotificationServiceProtocol {
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

fileprivate final class MockPostsProvider: PostsProviderProtocol {
    var posts: [Post] = []
    
    func getPosts() -> [Post] {
        return posts
    }
    
    func updatePosts(_ posts: [Post]) {
        self.posts = posts
    }
}

fileprivate final class MockReportStatusFactory: ReportStatusFactory {
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