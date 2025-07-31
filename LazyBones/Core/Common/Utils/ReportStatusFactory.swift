import Foundation

/// Фабрика для создания и управления статусами отчетов
class ReportStatusFactory {
    
    private let configProvider: ReportStatusConfigProvider
    
    init(configProvider: ReportStatusConfigProvider = DefaultReportStatusConfigProvider()) {
        self.configProvider = configProvider
    }
    
    /// Создает статус на основе текущего состояния
    func createStatus(
        hasRegularReport: Bool,
        isReportPublished: Bool,
        isPeriodActive: Bool,
        forceUnlock: Bool = false
    ) -> ReportStatus {
        
        let config = configProvider.config
        
        // Принудительная разблокировка
        if config.statusSettings.enableForceUnlock && forceUnlock {
            return .notStarted
        }
        
        // Логика определения статуса
        if hasRegularReport {
            if isPeriodActive {
                return isReportPublished ? .sent : .inProgress
            } else {
                return isReportPublished ? .sent : .notSent
            }
        } else {
            return isPeriodActive ? .notStarted : .notCreated
        }
    }
    
    /// Проверяет, активен ли период отчетности
    func isReportPeriodActive() -> Bool {
        let config = configProvider.config
        let calendar = Calendar.current
        let now = Date()
        
        let start = calendar.date(
            bySettingHour: config.timeSettings.startHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        let end = calendar.date(
            bySettingHour: config.timeSettings.endHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        return now >= start && now < end
    }
    
    /// Получает отображаемое имя для статуса
    func getDisplayName(for status: ReportStatus) -> String {
        return status.displayName
    }
    
    /// Получает цвет для статуса
    func getColor(for status: ReportStatus) -> String {
        switch status {
        case .notStarted, .notCreated, .notSent:
            return "gray"
        case .inProgress, .sent, .done:
            return "black"
        }
    }
    
    /// Проверяет, должен ли статус сбрасываться при новом дне
    func shouldResetOnNewDay(_ status: ReportStatus) -> Bool {
        let config = configProvider.config
        guard config.statusSettings.autoResetOnNewDay else { return false }
        
        return status == .sent || status == .notCreated || status == .notSent || status == .done
    }
} 