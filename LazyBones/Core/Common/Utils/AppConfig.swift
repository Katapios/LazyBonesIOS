import Foundation

/// Конфигурационные константы приложения
/// Здесь можно легко изменить bundle ID и app groups для всех компонентов
struct AppConfig {
    
    // MARK: - Bundle Identifiers
    
    /// Основной bundle ID приложения
    static let mainBundleId = "com.katapios.LazyBones"
    
    /// Bundle ID для виджета
    static let widgetBundleId = "com.katapios.LazyBones.LazyBonesWidget"
    
    /// Bundle ID для Watch App
    static let watchBundleId = "com.katapios.LazyBones.watchkitapp"
    
    // MARK: - App Groups
    
    /// App Group для общих данных между приложением и виджетом
    static let appGroup = "group.KP"
    
    // MARK: - Background Task Identifiers
    
    /// Идентификатор для background task отправки отчета
    static let backgroundTaskIdentifier = "com.katapios.LazyBones.sendReport"
    
    // MARK: - Widget Identifiers
    
    /// Идентификатор виджета
    static let widgetKind = "com.katapios.LazyBones.LazyBonesWidget"
    
    // MARK: - UserDefaults
    
    /// UserDefaults для app group
    static var sharedUserDefaults: UserDefaults {
        guard let shared = UserDefaults(suiteName: appGroup) else {
            print("[AppConfig] WARNING: Failed to create UserDefaults for app group '\(appGroup)', falling back to standard")
            return UserDefaults.standard
        }
        return shared
    }
} 
