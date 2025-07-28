import Foundation
import SwiftUI

/// Базовый протокол для всех координаторов
protocol CoordinatorProtocol: ObservableObject {
    func start()
    func stop()
}

/// Протокол для координаторов с поддержкой навигации
protocol NavigationCoordinatorProtocol: CoordinatorProtocol {
    var navigationPath: NavigationPath { get set }
    
    func navigate(to destination: any Hashable)
    func navigateBack()
    func navigateToRoot()
}

/// Протокол для координаторов с поддержкой модальной презентации
protocol ModalCoordinatorProtocol: CoordinatorProtocol {
    var isPresented: Bool { get set }
    
    func present()
    func dismiss()
}

/// Протокол для координаторов с поддержкой вложенных координаторов
protocol ParentCoordinatorProtocol: CoordinatorProtocol {
    var childCoordinators: [CoordinatorProtocol] { get set }
    
    func addChild(_ coordinator: CoordinatorProtocol)
    func removeChild(_ coordinator: CoordinatorProtocol)
} 