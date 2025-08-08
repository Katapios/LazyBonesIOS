import Foundation

/// Use case для получения настроек Telegram
public final class GetTelegramSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Получить текущие настройки Telegram
    /// - Returns: Текущие настройки Telegram
    public func execute() async throws -> TelegramSettings {
        try await settingsRepository.getTelegramSettings()
    }
}
