import Foundation

/// Use case для обновления настроек Telegram
public final class UpdateTelegramSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Обновить настройки Telegram
    /// - Parameter settings: Новые настройки Telegram
    public func execute(_ settings: TelegramSettings) async throws {
        try await settingsRepository.updateTelegramSettings(settings)
    }
}
