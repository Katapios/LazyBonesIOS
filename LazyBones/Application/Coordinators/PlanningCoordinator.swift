import Foundation
import SwiftUI

/// Координатор для вкладки планирования
@MainActor
class PlanningCoordinator: BaseCoordinator {
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    override func start() {
        Logger.debug("PlanningCoordinator started", log: Logger.ui)
        // Инициализация вкладки планирования
    }
    
    func showDailyPlanningForm() {
        // TODO: Создать DailyPlanningViewModel и DailyPlanningFormView
        Logger.debug("Showing daily planning form", log: Logger.ui)
    }
    
    func showPlanningHistory() {
        // Показать историю планирования
        Logger.debug("Showing planning history", log: Logger.ui)
    }
} 