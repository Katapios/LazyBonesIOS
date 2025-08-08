import Foundation

/// Use case для получения основных настроек приложения
public final class GetAppSettingsUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Получить текущие основные настройки приложения
    /// - Returns: Текущие основные настройки
    public func execute() async throws -> AppSettings {
        try await settingsRepository.getAppSettings()
    }
}
