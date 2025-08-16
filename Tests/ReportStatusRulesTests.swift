import XCTest
@testable import LazyBones

final class ReportStatusRulesTests: XCTestCase {
    // MARK: - Mocks
    // Удалён RS_LocalServiceMock: базовый класс имеет private init, используем LocalReportService.shared
    
    final class RS_PostsProviderMock: PostsProviderProtocol {
        var posts: [Post] = []
        func getPosts() -> [Post] { posts }
        func updatePosts(_ posts: [Post]) { self.posts = posts }
    }
    
    final class RS_TimerServiceMock: PostTimerServiceProtocol {
        var timeLeft: String { "" }
        var timeProgress: Double { 0.0 }
        func updateReportStatus(_ status: ReportStatus) {}
        func updateTimeLeft() {}
        func startTimer() {}
        func stopTimer() {}
    }
    
    final class RS_NotificationServiceMock: PostNotificationServiceProtocol {
        func scheduleNotifications() {}
        func scheduleNotificationsIfNeeded() {}
        func cancelAllNotifications() {}
        func cancelNotification(identifier: String) {}
        func getPendingNotifications() async -> [UNNotificationRequest] { return [] }
        func getDeliveredNotifications() async -> [UNNotification] { return [] }
    }
    
    final class RS_StatusFactoryMock: ReportStatusFactory {
        var isActive: Bool = true
        override func isReportPeriodActive() -> Bool { isActive }
    }
    
    // Helpers
    private func makeManager(isActive: Bool, posts: [Post], forceUnlock: Bool = false) -> (ReportStatusManager, LocalReportService, RS_StatusFactoryMock) {
        let local = LocalReportService.shared
        local.saveForceUnlock(forceUnlock)
        let timer = RS_TimerServiceMock()
        let notif = RS_NotificationServiceMock()
        let provider = RS_PostsProviderMock()
        provider.posts = posts
        let factory = RS_StatusFactoryMock()
        factory.isActive = isActive
        let mgr = ReportStatusManager(
            localService: local,
            timerService: timer,
            notificationService: notif,
            postsProvider: provider,
            factory: factory
        )
        return (mgr, local, factory)
    }
    
    private func makePost(published: Bool) -> Post {
        return Post(
            id: UUID(),
            date: Date(),
            goodItems: ["A"],
            badItems: ["B"],
            published: published,
            voiceNotes: [],
            type: .regular
        )
    }
    
    // MARK: - Tests (из README)
    func test_activePeriod_empty_notStarted() {
        let (mgr, _, _) = makeManager(isActive: true, posts: [])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .notStarted)
    }
    
    func test_activePeriod_draft_inProgress() {
        let (mgr, _, _) = makeManager(isActive: true, posts: [makePost(published: false)])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .inProgress)
    }
    
    func test_activePeriod_published_sent() {
        let (mgr, _, _) = makeManager(isActive: true, posts: [makePost(published: true)])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .sent)
    }
    
    func test_inactivePeriod_empty_notCreated() {
        let (mgr, _, _) = makeManager(isActive: false, posts: [])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .notCreated)
    }
    
    func test_inactivePeriod_draft_notSent() {
        let (mgr, _, _) = makeManager(isActive: false, posts: [makePost(published: false)])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .notSent)
    }
    
    func test_inactivePeriod_published_sent() {
        let (mgr, _, _) = makeManager(isActive: false, posts: [makePost(published: true)])
        mgr.updateStatus()
        XCTAssertEqual(mgr.reportStatus, .sent)
    }
    
    func test_forceUnlock_keepsEditable_untilSend_thenResets() {
        // Вне периода, есть черновик, forceUnlock=true => должен быть редактируемый статус
        var (mgr, local, _) = makeManager(isActive: false, posts: [makePost(published: false)], forceUnlock: true)
        mgr.updateStatus()
        XCTAssertTrue(mgr.forceUnlock)
        XCTAssertEqual(mgr.reportStatus, .inProgress) // Разрешено редактировать
        
        // Имитируем отправку: делаем пост опубликованным
        let sent = makePost(published: true)
        // Переинициализируем менеджер с тем же local (чтобы проверить сброс forceUnlock)
        (mgr, local, _) = makeManager(isActive: false, posts: [sent], forceUnlock: local.getForceUnlock())
        mgr.updateStatus()
        
        XCTAssertEqual(mgr.reportStatus, .sent)
        XCTAssertFalse(local.getForceUnlock())
        XCTAssertFalse(mgr.forceUnlock)
    }
}
