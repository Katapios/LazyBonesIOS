import Foundation

final class PlanningRepository: PlanningRepositoryProtocol {
    private let dataSource: PlanningLocalDataSource
    
    init(dataSource: PlanningLocalDataSource) {
        self.dataSource = dataSource
    }
    
    func loadPlan(for date: Date) -> [String] {
        dataSource.loadPlan(for: date)
    }
    
    func savePlan(_ items: [String], for date: Date) {
        dataSource.savePlan(items, for: date)
    }
}
