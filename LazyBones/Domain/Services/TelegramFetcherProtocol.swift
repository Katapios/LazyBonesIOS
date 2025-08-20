import Foundation

/// Абстракция получения внешних отчётов из Telegram для Domain слоя
protocol TelegramFetcherProtocol {
    /// Выполняет получение новых внешних сообщений из Telegram и возвращает их в доменной модели
    func fetchNewExternalPosts() async throws -> [DomainPost]
}
