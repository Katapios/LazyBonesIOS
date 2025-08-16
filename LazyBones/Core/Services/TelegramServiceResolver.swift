import Foundation

protocol TelegramServiceResolverProtocol {
    func resolveTelegramService() -> TelegramServiceProtocol?
}

final class TelegramServiceResolver: TelegramServiceResolverProtocol {
    func resolveTelegramService() -> TelegramServiceProtocol? {
        DependencyContainer.shared.resolve(TelegramServiceProtocol.self)
    }
}
