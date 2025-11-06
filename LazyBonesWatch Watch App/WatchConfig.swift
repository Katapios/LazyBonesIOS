import Foundation

/// Конфигурационные константы для Watch App
/// Использует константы из основного приложения для избежания дублирования
struct WatchConfig {
    
    // MARK: - App Groups
    
    /// App Group для общих данных между приложением, виджетом и Watch
    static let appGroup = "group.KP"
    
    // MARK: - Watch Identifiers
    
    /// Идентификатор Watch App
    static let watchBundleId = "com.katapios.LazyBones.watchkitapp"
    
    // MARK: - UserDefaults
    
    /// UserDefaults для app group
    static var sharedUserDefaults: UserDefaults {
        guard let shared = UserDefaults(suiteName: appGroup) else {
            #if DEBUG
            print("[WatchConfig] WARNING: Failed to create UserDefaults for app group '\(appGroup)', falling back to standard")
            #endif
            return UserDefaults.standard
        }
        return shared
    }
    
    // MARK: - WatchConnectivity
    
    /// Идентификатор для WatchConnectivity сессии
    static let watchConnectivitySessionIdentifier = "com.katapios.LazyBones.watch"
}

