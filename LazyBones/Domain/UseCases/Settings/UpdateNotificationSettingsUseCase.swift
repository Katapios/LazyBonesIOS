import Foundation

/// Use case для обновления настроек уведомлений
public final class UpdateNotificationSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Обновить настройки уведомлений
    /// - Parameter settings: Новые настройки уведомлений
    public func execute(_ settings: NotificationSettings) async throws {
        try await settingsRepository.updateNotificationSettings(settings)
    }
}
