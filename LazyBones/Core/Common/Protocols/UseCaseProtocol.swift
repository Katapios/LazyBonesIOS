import Foundation

/// Базовый протокол для всех Use Cases
protocol UseCaseProtocol {
    associatedtype Input
    associatedtype Output
    associatedtype ErrorType: Error
    
    func execute(input: Input) async throws -> Output
}

/// Протокол для Use Cases без входных параметров
protocol UseCaseWithoutInputProtocol {
    associatedtype Output
    associatedtype ErrorType: Error
    
    func execute() async throws -> Output
}

/// Протокол для Use Cases с асинхронным выполнением
protocol AsyncUseCaseProtocol {
    associatedtype Input
    associatedtype Output
    associatedtype ErrorType: Error
    
    func execute(input: Input) async throws -> Output
}

/// Протокол для Use Cases с поддержкой отмены
protocol CancellableUseCaseProtocol: AsyncUseCaseProtocol {
    func cancel()
} 