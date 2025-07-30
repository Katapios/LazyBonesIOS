import Foundation

/// Конфигурационные константы для виджета
/// Дублируем константы из основного приложения для виджета
struct WidgetConfig {
    
    // MARK: - App Groups
    
    /// App Group для общих данных между приложением и виджетом
    static let appGroup = "group.com.katapios.LazyBones"
    
    // MARK: - Widget Identifiers
    
    /// Идентификатор виджета
    static let widgetKind = "com.katapios.LazyBones1.LazyBonesWidget"
    
    // MARK: - UserDefaults
    
    /// UserDefaults для app group
    static var sharedUserDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    }
} 
