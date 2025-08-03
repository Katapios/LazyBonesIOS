import XCTest
@testable import LazyBones

class CoordinatorTests: XCTestCase {
    
    var coordinator: TestCoordinator!
    var mockNavigationController: MockNavigationController!
    
    override func setUp() {
        super.setUp()
        mockNavigationController = MockNavigationController()
        coordinator = TestCoordinator(navigationController: mockNavigationController)
    }
    
    override func tearDown() {
        coordinator = nil
        mockNavigationController = nil
        super.tearDown()
    }
    
    func testAddChildCoordinator() {
        // Given
        let childCoordinator = TestCoordinator()
        
        // When
        coordinator.addChildCoordinator(childCoordinator)
        
        // Then
        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        XCTAssertTrue(coordinator.childCoordinators.first === childCoordinator)
    }
    
    func testRemoveChildCoordinator() {
        // Given
        let childCoordinator = TestCoordinator()
        coordinator.addChildCoordinator(childCoordinator)
        
        // When
        coordinator.removeChildCoordinator(childCoordinator)
        
        // Then
        XCTAssertEqual(coordinator.childCoordinators.count, 0)
    }
    
    func testFinishRemovesAllChildCoordinators() {
        // Given
        let child1 = TestCoordinator()
        let child2 = TestCoordinator()
        coordinator.addChildCoordinator(child1)
        coordinator.addChildCoordinator(child2)
        
        // When
        coordinator.finish()
        
        // Then
        XCTAssertEqual(coordinator.childCoordinators.count, 0)
    }
    
    func testErrorHandlingCoordinator() {
        // Given
        let errorCoordinator = TestErrorHandlingCoordinator(navigationController: mockNavigationController)
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
        
        // When
        errorCoordinator.handleError(testError)
        
        // Then
        XCTAssertEqual(errorCoordinator.lastError?.localizedDescription, testError.localizedDescription)
    }
    
    func testLoadingCoordinator() {
        // Given
        let loadingCoordinator = TestLoadingCoordinator(navigationController: mockNavigationController)
        
        // When
        loadingCoordinator.showLoading()
        
        // Then
        XCTAssertTrue(loadingCoordinator.isLoading)
        
        // When
        loadingCoordinator.hideLoading()
        
        // Then
        XCTAssertFalse(loadingCoordinator.isLoading)
    }
}

// MARK: - Test Implementations

class TestCoordinator: BaseCoordinator {
    var startCalled = false
    
    override func start() {
        startCalled = true
    }
}

class TestErrorHandlingCoordinator: BaseCoordinator, ErrorHandlingCoordinator {
    var lastError: Error?
    
    func handleError(_ error: Error) {
        lastError = error
    }
    
    func clearError() {
        lastError = nil
    }
}

class TestLoadingCoordinator: BaseCoordinator, LoadingCoordinator {
    var isLoading: Bool = false
    
    func showLoading() {
        isLoading = true
    }
    
    func hideLoading() {
        isLoading = false
    }
}

class MockNavigationController: UINavigationController {
    var pushedViewControllers: [UIViewController] = []
    var presentedViewControllers: [UIViewController] = []
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushedViewControllers.append(viewController)
        super.pushViewController(viewController, animated: animated)
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedViewControllers.append(viewControllerToPresent)
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
} 