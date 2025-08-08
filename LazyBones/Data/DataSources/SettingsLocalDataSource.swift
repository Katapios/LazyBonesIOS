import Foundation

/// Протокол для локального хранения настроек
public protocol SettingsLocalDataSourceProtocol {
    /// Загрузить настройки
    func loadSettings() throws -> SettingsDataModel
    
    /// Сохранить настройки
    /// - Parameter settings: Настройки для сохранения
    func saveSettings(_ settings: SettingsDataModel) throws
    
    /// Очистить все настройки
    func clearAllSettings() throws
}

/// Источник данных для работы с настройками в UserDefaults
public final class SettingsLocalDataSource: SettingsLocalDataSourceProtocol {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let settingsKey: String
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard, settingsKey: String = "com.lazybones.settings") {
        self.userDefaults = userDefaults
        self.settingsKey = settingsKey
    }
    
    // MARK: - SettingsLocalDataSourceProtocol
    
    public func loadSettings() throws -> SettingsDataModel {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            // Возвращаем настройки по умолчанию, если ничего не сохранено
            return SettingsDataModel()
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SettingsDataModel.self, from: data)
        } catch {
            // В случае ошибки десериализации возвращаем настройки по умолчанию
            // и логируем ошибку
            print("Failed to decode settings: \(error)")
            return SettingsDataModel()
        }
    }
    
    public func saveSettings(_ settings: SettingsDataModel) throws {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            userDefaults.synchronize()
        } catch {
            print("Failed to encode settings: \(error)")
            throw error
        }
    }
    
    public func clearAllSettings() throws {
        userDefaults.removeObject(forKey: settingsKey)
        userDefaults.synchronize()
    }
}
