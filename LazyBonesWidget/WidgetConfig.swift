import Foundation

/// Конфигурационные константы для виджета
/// Использует константы из основного приложения для избежания дублирования
struct WidgetConfig {
    
    // MARK: - App Groups (из основного приложения)
    
    /// App Group для общих данных между приложением и виджетом
    /// Использует то же значение, что и в основном приложении
    static let appGroup = "group.com.H2GFBK2X44.loopkit.LoopGroup"
    
    // MARK: - Widget Identifiers
    
    /// Идентификатор основного виджета (Timeline)
    static let primaryWidgetKind = "com.katapios.LazyBones.LazyBonesWidget"
    /// Идентификатор управляемого виджета (ControlWidget)
    static let controlWidgetKind = "com.katapios.LazyBones.LazyBonesWidget.Control"
    /// Для обратной совместимости (не использовать в новых местах)
    static let widgetKind = primaryWidgetKind
    
    // MARK: - UserDefaults
    
    /// UserDefaults для app group
    static var sharedUserDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    }
} 
