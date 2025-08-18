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
    
    // Навигация к подэкранu Telegram/Уведомлений временно не используется,
    // т.к. `SettingsView` инлайнит соответствующие секции в одну форму.
    // Если будет принято решение разнести настройки по экранам — добавить методы навигации обратно.
    
    func showTagManager() {
        // TagManagerView уже существует, но не принимает viewModel
        Logger.debug("Showing tag manager", log: Logger.ui)
    }
}
 