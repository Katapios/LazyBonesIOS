import Foundation
import SwiftUI

/// Координатор для главной вкладки
@MainActor
class MainCoordinator: BaseCoordinator {
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    override func start() {
        Logger.debug("MainCoordinator started", log: Logger.ui)
        // Инициализация главной вкладки
    }
    
    func showReportForm() {
        // TODO: Создать CreateReportViewModel и CreateReportView
        Logger.debug("Showing report form", log: Logger.ui)
    }
    
    func showStatusDetails() {
        // Показать детали статуса отчета
        Logger.debug("Showing status details", log: Logger.ui)
    }
} 