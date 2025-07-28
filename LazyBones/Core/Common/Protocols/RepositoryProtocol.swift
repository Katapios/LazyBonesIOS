import Foundation

/// Базовый протокол для всех репозиториев
protocol RepositoryProtocol {
    associatedtype Model
    associatedtype ErrorType: Error
    
    func fetch() async throws -> [Model]
    func save(_ models: [Model]) async throws
    func delete(_ model: Model) async throws
    func clear() async throws
}

/// Протокол для репозиториев с поддержкой CRUD операций
protocol CRUDRepositoryProtocol: RepositoryProtocol {
    func create(_ model: Model) async throws
    func read(id: String) async throws -> Model?
    func update(_ model: Model) async throws
}

/// Протокол для репозиториев с поддержкой поиска
protocol SearchableRepositoryProtocol: RepositoryProtocol {
    func search(query: String) async throws -> [Model]
    func filter(predicate: @escaping (Model) -> Bool) async throws -> [Model]
} 