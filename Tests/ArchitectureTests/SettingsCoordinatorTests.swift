import XCTest
import SwiftUI
@testable import LazyBones

@MainActor
final class SettingsCoordinatorTests: XCTestCase {
    var coordinator: SettingsCoordinator!
    var nav: UINavigationController!

    override func setUp() {
        super.setUp()
        let container = DependencyContainer.shared
        coordinator = SettingsCoordinator(dependencyContainer: container)
        nav = UINavigationController()
        coordinator.navigationController = nav
    }

    override func tearDown() {
        coordinator = nil
        nav = nil
        super.tearDown()
    }

    func testShowTelegramSettings_PushesHostingController() {
        // When
        coordinator.showTelegramSettings()

        // Then
        XCTAssertEqual(nav.viewControllers.count, 1)
        let vc = nav.viewControllers.last
        XCTAssertTrue(vc is UIHostingController<any View>)
        XCTAssertEqual(vc?.title, "Telegram")
    }

    func testShowNotificationSettings_PushesHostingController() {
        // When
        coordinator.showNotificationSettings()

        // Then
        XCTAssertEqual(nav.viewControllers.count, 1)
        let vc = nav.viewControllers.last
        XCTAssertTrue(vc is UIHostingController<any View>)
        XCTAssertEqual(vc?.title, "Уведомления")
    }
}
