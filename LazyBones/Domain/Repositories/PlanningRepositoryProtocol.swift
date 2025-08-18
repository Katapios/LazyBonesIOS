import Foundation

public protocol PlanningRepositoryProtocol {
    func loadPlan(for date: Date) -> [String]
    func savePlan(_ items: [String], for date: Date)
}
