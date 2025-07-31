import Foundation

/// Конфигурация для статусной модели отчетов
struct ReportStatusConfig {
    
    // MARK: - Временные настройки
    struct TimeSettings {
        let startHour: Int
        let endHour: Int
        let timeZone: TimeZone
        
        static let `default` = TimeSettings(
            startHour: 8,
            endHour: 22,
            timeZone: .current
        )
    }
    
    // MARK: - Настройки статусов
    struct StatusSettings {
        let enableForceUnlock: Bool
        let autoResetOnNewDay: Bool
        let enableNotifications: Bool
        
        static let `default` = StatusSettings(
            enableForceUnlock: true,
            autoResetOnNewDay: true,
            enableNotifications: true
        )
    }
    
    // MARK: - Настройки UI
    struct UISettings {
        let showTimer: Bool
        let showProgress: Bool
        let enableWidgetUpdates: Bool
        
        static let `default` = UISettings(
            showTimer: true,
            showProgress: true,
            enableWidgetUpdates: true
        )
    }
    
    let timeSettings: TimeSettings
    let statusSettings: StatusSettings
    let uiSettings: UISettings
    
    static let `default` = ReportStatusConfig(
        timeSettings: .default,
        statusSettings: .default,
        uiSettings: .default
    )
}

/// Протокол для получения конфигурации статусной модели
protocol ReportStatusConfigProvider {
    var config: ReportStatusConfig { get }
}

/// Реализация провайдера конфигурации
class DefaultReportStatusConfigProvider: ReportStatusConfigProvider {
    let config: ReportStatusConfig
    
    init(config: ReportStatusConfig = .default) {
        self.config = config
    }
} 