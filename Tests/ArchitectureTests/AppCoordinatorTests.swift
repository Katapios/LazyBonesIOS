import XCTest
@testable import LazyBones

@MainActor
class AppCoordinatorTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var mockDependencyContainer: MockDependencyContainer!
    
    override func setUp() {
        super.setUp()
        mockDependencyContainer = MockDependencyContainer()
        coordinator = AppCoordinator(dependencyContainer: mockDependencyContainer)
    }
    
    override func tearDown() {
        coordinator = nil
        mockDependencyContainer = nil
        super.tearDown()
    }
    
    func testSwitchToTab_CreatesChildCoordinator() {
        // Given
        let tab = AppCoordinator.Tab.planning
        
        // When
        coordinator.switchToTab(tab)
        
        // Then
        XCTAssertEqual(coordinator.currentTab, tab)
        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        XCTAssertTrue(coordinator.childCoordinators.first is PlanningCoordinator)
    }
    
    func testSwitchToTab_RemovesPreviousChildCoordinator() {
        // Given
        coordinator.switchToTab(.main)
        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        
        // When
        coordinator.switchToTab(.planning)
        
        // Then
        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        XCTAssertTrue(coordinator.childCoordinators.first is PlanningCoordinator)
    }
    
    func testStart_InitializesServices() async {
        // Given
        let mockBackgroundService = MockBackgroundTaskService()
        let mockNotificationService = MockNotificationManagerService()
        mockDependencyContainer.mockService(mockBackgroundService, for: BackgroundTaskServiceProtocol.self)
        mockDependencyContainer.mockService(mockNotificationService, for: NotificationManagerServiceType.self)
        
        // When
        await coordinator.start()
        
        // Then
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertEqual(coordinator.currentTab, .main)
        XCTAssertTrue(mockBackgroundService.registerBackgroundTasksCalled)
        XCTAssertTrue(mockNotificationService.requestNotificationPermissionAndScheduleCalled)
    }
    
    func testStart_HandlesErrors() async {
        // Given
        let mockBackgroundService = MockBackgroundTaskService()
        mockBackgroundService.shouldThrowError = true
        mockDependencyContainer.mockService(mockBackgroundService, for: BackgroundTaskServiceProtocol.self)
        
        // When
        await coordinator.start()
        
        // Then
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isLoading)
    }
    
    func testHandleError_SetsErrorMessage() {
        // Given
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        coordinator.handleError(testError)
        
        // Then
        XCTAssertEqual(coordinator.errorMessage, "Test error")
    }
    
    func testClearError_RemovesErrorMessage() {
        // Given
        coordinator.errorMessage = "Test error"
        
        // When
        coordinator.clearError()
        
        // Then
        XCTAssertNil(coordinator.errorMessage)
    }
    
    func testShowLoading_SetsLoadingState() {
        // When
        coordinator.showLoading()
        
        // Then
        XCTAssertTrue(coordinator.isLoading)
    }
    
    func testHideLoading_ClearsLoadingState() {
        // Given
        coordinator.isLoading = true
        
        // When
        coordinator.hideLoading()
        
        // Then
        XCTAssertFalse(coordinator.isLoading)
    }
    
    func testFinish_RemovesAllChildCoordinators() {
        // Given
        coordinator.switchToTab(.main)
        coordinator.switchToTab(.planning)
        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        
        // When
        coordinator.finish()
        
        // Then
        XCTAssertEqual(coordinator.childCoordinators.count, 0)
    }
}

// MARK: - Mock Implementations

class MockDependencyContainer: DependencyContainer {
    var resolvedServices: [String: Any] = [:]
    
    override func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return resolvedServices[key] as? T
    }
    
    func mockService<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        resolvedServices[key] = service
    }
}

class MockBackgroundTaskService: BackgroundTaskServiceProtocol {
    var registerBackgroundTasksCalled = false
    var shouldThrowError = false
    
    func registerBackgroundTasks() throws {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        registerBackgroundTasksCalled = true
    }
    
    func scheduleSendReportTask() throws {
        // Not implemented for this test
    }
}

class MockNotificationManagerService: NotificationManagerServiceType {
    var requestNotificationPermissionAndScheduleCalled = false
    
    func requestNotificationPermissionAndSchedule() async {
        requestNotificationPermissionAndScheduleCalled = true
    }
    
    // Implement other required methods with default values
    var notificationsEnabled: Bool = false
    var notificationMode: NotificationMode = .hourly
    var notificationIntervalHours: Int = 1
    var notificationStartHour: Int = 8
    var notificationEndHour: Int = 22
    
    func saveNotificationSettings() {
        // Not implemented for this test
    }
    
    func loadNotificationSettings() {
        // Not implemented for this test
    }
    
    func scheduleNotifications() {
        // Not implemented for this test
    }
    
    func cancelAllNotifications() {
        // Not implemented for this test
    }
} 