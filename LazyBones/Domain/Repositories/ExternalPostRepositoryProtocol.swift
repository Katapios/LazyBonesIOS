import Foundation

/// Репозиторий для внешних отчётов (Telegram)
protocol ExternalPostRepositoryProtocol {
    func fetchAll() async throws -> [DomainPost]
    func fetch(for date: Date) async throws -> [DomainPost]
    func saveAll(_ posts: [DomainPost]) async throws
    func clear() async throws
}
