import Foundation
import SwiftUI

/// Координатор для вкладки тегов
@MainActor
class TagsCoordinator: BaseCoordinator {
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    override func start() {
        Logger.debug("TagsCoordinator started", log: Logger.ui)
        // Инициализация вкладки тегов
    }
    
    func showTagManager() {
        // TagManagerView уже существует, но не принимает viewModel
        Logger.debug("Showing tag manager", log: Logger.ui)
    }
    
    /// Собирает экран менеджера тегов на новой архитектуре
    func makeTagManagerView() -> some View {
        let vm = dependencyContainer.resolve(TagManagerViewModelNew.self)!
        return TagManagerViewClean(viewModel: vm)
    }
    
    func showTagStatistics() {
        // Показать статистику использования тегов
        Logger.debug("Showing tag statistics", log: Logger.ui)
    }
} 