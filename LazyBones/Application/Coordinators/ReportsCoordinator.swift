import Foundation
import SwiftUI

/// Координатор для вкладки отчетов
@MainActor
class ReportsCoordinator: BaseCoordinator {
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    override func start() {
        Logger.debug("ReportsCoordinator started", log: Logger.ui)
        // Инициализация вкладки отчетов
    }
    
    func showReportDetails(_ report: DomainPost) {
        // TODO: Создать ReportDetailsViewModel и ReportDetailsView
        Logger.debug("Showing report details for: \(report.id)", log: Logger.ui)
    }
    
    func showReportList() {
        // ReportListView уже существует и принимает viewModel
        Logger.debug("Showing report list", log: Logger.ui)
    }
    
    func showReportStatistics() {
        // Показать статистику отчетов
        Logger.debug("Showing report statistics", log: Logger.ui)
    }
} 