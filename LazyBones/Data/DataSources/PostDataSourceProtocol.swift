import Foundation

/// Протокол для источника данных отчетов
protocol PostDataSourceProtocol {
    func save(_ posts: [Post]) async throws
    func load() async throws -> [Post]
    func clear() async throws
}

/// Протокол для локального хранилища
protocol LocalStorageProtocol {
    func save<T: Codable>(_ data: T, forKey key: String) async throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T?
    func remove(forKey key: String) async throws
    func clear() async throws
} 