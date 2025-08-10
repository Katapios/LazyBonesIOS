import Foundation
import SwiftUI

/// Координатор для вкладки настроек
@MainActor
class SettingsCoordinator: BaseCoordinator {
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    override func start() {
        Logger.debug("SettingsCoordinator started", log: Logger.ui)
        // Инициализация вкладки настроек
    }
    
    func showTelegramSettings() {
        Logger.debug("Showing Telegram settings", log: Logger.ui)
        let view = TelegramSettingsView()
        let hosting = UIHostingController(rootView: view)
        hosting.title = "Telegram"
        navigationController?.pushViewController(hosting, animated: true)
    }
    
    func showNotificationSettings() {
        Logger.debug("Showing notification settings", log: Logger.ui)
        let view = NotificationSettingsView()
        let hosting = UIHostingController(rootView: view)
        hosting.title = "Уведомления"
        navigationController?.pushViewController(hosting, animated: true)
    }
    
    func showTagManager() {
        // TagManagerView уже существует, но не принимает viewModel
        Logger.debug("Showing tag manager", log: Logger.ui)
    }
}
 