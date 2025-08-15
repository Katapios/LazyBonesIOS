import Foundation

/// Абстракция для обновления Telegram-конфигурации (DI/сервисы) без утечки в Presentation слой
protocol TelegramConfigUpdaterProtocol {
    /// Применить новый токен Telegram: зарегистрировать/удалить сервис и обновить зависящие компоненты
    func applyTelegramToken(_ token: String?)
}

/// Реализация уровня Infrastructure: инкапсулирует DI и PostStore
final class TelegramConfigUpdater: TelegramConfigUpdaterProtocol {
    private let container: DependencyContainer
    
    init(container: DependencyContainer = .shared) {
        self.container = container
    }
    
    func applyTelegramToken(_ token: String?) {
        // Регистрируем/удаляем TelegramService в DI
        if let token, !token.isEmpty {
            container.registerTelegramService(token: token)
        } else {
            // ВАЖНО: не удаляем фабрику/сервис из DI, чтобы не падали force unwrap в фабриках.
            // Регистрируем пустой сервис, который безопасно резолвится.
            container.registerTelegramService(token: "")
        }
        
        // Обновляем зависимости, которые используют TelegramService (в инфраструктуре)
        PostStore.shared.refreshTelegramServices()
    }
}
