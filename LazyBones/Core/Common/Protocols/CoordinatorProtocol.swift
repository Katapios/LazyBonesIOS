import Foundation
import UIKit

/// Базовый протокол для всех координаторов
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController? { get }
    
    func start()
    func finish()
}

/// Базовый класс для координаторов
class BaseCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    init(navigationController: UINavigationController? = nil) {
        self.navigationController = navigationController
    }
    
    func start() {
        // Override in subclasses
    }
    
    func finish() {
        childCoordinators.removeAll()
    }
    
    func addChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }
    
    func removeChildCoordinator(_ coordinator: Coordinator) {
        if let index = childCoordinators.firstIndex(where: { $0 === coordinator }) {
            childCoordinators.remove(at: index)
        }
    }
}

/// Протокол для координаторов с поддержкой ошибок
protocol ErrorHandlingCoordinator: Coordinator {
    func handleError(_ error: Error)
    func clearError()
}

/// Протокол для координаторов с состоянием загрузки
protocol LoadingCoordinator: Coordinator {
    var isLoading: Bool { get set }
    func showLoading()
    func hideLoading()
} 