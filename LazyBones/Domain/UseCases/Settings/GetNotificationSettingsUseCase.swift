import Foundation

/// Use case для получения настроек уведомлений
public final class GetNotificationSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Получить текущие настройки уведомлений
    /// - Returns: Текущие настройки уведомлений
    public func execute() async throws -> NotificationSettings {
        try await settingsRepository.getNotificationSettings()
    }
}
