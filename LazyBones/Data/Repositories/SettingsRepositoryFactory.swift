import Foundation

/// Фабрика для создания экземпляров SettingsRepository
public final class SettingsRepositoryFactory {
    
    // MARK: - Public Methods
    
    /// Создает и возвращает экземпляр SettingsRepository
    /// - Returns: Настроенный экземпляр SettingsRepository
    public static func makeSettingsRepository() -> SettingsRepositoryProtocol {
        return SettingsRepository()
    }
    
    /// Создает и возвращает экземпляр SettingsRepository с пользовательскими зависимостями
    /// - Parameters:
    ///   - localDataSource: Источник данных для локального хранилища
    ///   - fileManager: Менеджер файловой системы
    /// - Returns: Настроенный экземпляр SettingsRepository
    public static func makeSettingsRepository(
        localDataSource: SettingsLocalDataSourceProtocol = SettingsLocalDataSource(),
        fileManager: FileManager = .default
    ) -> SettingsRepositoryProtocol {
        return SettingsRepository(
            localDataSource: localDataSource,
            fileManager: fileManager
        )
    }
}
