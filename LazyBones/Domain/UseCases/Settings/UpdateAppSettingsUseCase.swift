import Foundation

/// Use case для обновления основных настроек приложения
public final class UpdateAppSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Обновить основные настройки приложения
    /// - Parameter settings: Новые основные настройки
    public func execute(_ settings: AppSettings) async throws {
        try await settingsRepository.updateAppSettings(settings)
    }
}
