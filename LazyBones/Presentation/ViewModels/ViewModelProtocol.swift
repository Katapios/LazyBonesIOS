import Foundation
import SwiftUI

/// Базовый протокол для ViewModels
@preconcurrency
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Event
    
    var state: State { get set }
    
    func handle(_ event: Event) async
}

/// Базовый класс для ViewModels с состоянием
@MainActor
class BaseViewModel<State, Event>: ObservableObject, ViewModelProtocol {
    @Published var state: State
    
    init(initialState: State) {
        self.state = initialState
    }
    
    func handle(_ event: Event) async {
        // Override in subclasses
    }
}

/// Протокол для ViewModels с загрузкой данных
protocol LoadableViewModel: ViewModelProtocol {
    var isLoading: Bool { get set }
    var error: Error? { get set }
    
    func load() async
} 