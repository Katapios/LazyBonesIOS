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
        // TODO: Создать TelegramSettingsViewModel и TelegramSettingsView
        Logger.debug("Showing Telegram settings", log: Logger.ui)
    }
    
    func showNotificationSettings() {
        // TODO: Создать NotificationSettingsViewModel и NotificationSettingsView
        Logger.debug("Showing notification settings", log: Logger.ui)
    }
    
    func showTagManager() {
        // TagManagerView уже существует, но не принимает viewModel
        Logger.debug("Showing tag manager", log: Logger.ui)
    }
} 