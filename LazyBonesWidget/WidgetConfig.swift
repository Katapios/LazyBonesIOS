import Foundation

/// Конфигурационные константы для виджета
/// Дублируем константы из основного приложения для виджета
struct WidgetConfig {
    
    // MARK: - App Groups
    
    /// App Group для общих данных между приложением и виджетом
    static let appGroup = "group.com.katapios.LazyBones"
    
    // MARK: - Widget Identifiers
    
    /// Идентификатор основного виджета (Timeline)
    static let primaryWidgetKind = "com.katapios.LazyBones2.LazyBonesWidget"
    /// Идентификатор управляемого виджета (ControlWidget)
    static let controlWidgetKind = "com.katapios.LazyBones2.LazyBonesWidget.Control"
    /// Для обратной совместимости (не использовать в новых местах)
    static let widgetKind = primaryWidgetKind
    
    // MARK: - UserDefaults
    
    /// UserDefaults для app group
    static var sharedUserDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    }
} 
