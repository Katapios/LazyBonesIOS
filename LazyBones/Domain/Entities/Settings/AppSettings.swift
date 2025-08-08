import Foundation

/// Основные настройки приложения
public struct AppSettings: Equatable, Codable {
    /// Имя устройства
    public var deviceName: String
    /// Включен ли режим принудительной разблокировки
    public var isForceUnlockEnabled: Bool
    /// Включено ли тестирование фонового обновления
    public var isBackgroundFetchTestEnabled: Bool
    
    public init(
        deviceName: String = "",
        isForceUnlockEnabled: Bool = false,
        isBackgroundFetchTestEnabled: Bool = false
    ) {
        self.deviceName = deviceName
        self.isForceUnlockEnabled = isForceUnlockEnabled
        self.isBackgroundFetchTestEnabled = isBackgroundFetchTestEnabled
    }
}
