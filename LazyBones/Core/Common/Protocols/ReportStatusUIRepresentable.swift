import SwiftUI

/// Протокол для UI компонентов, отображающих статус отчетов
protocol ReportStatusUIRepresentable {
    var status: ReportStatus { get }
    var displayName: String { get }
    var color: Color { get }
    var isEnabled: Bool { get }
    var showTimer: Bool { get }
    var timerLabel: String { get }
    var timerValue: String { get }
    var progress: Double { get }
}

/// Расширение для ReportStatus с UI свойствами
extension ReportStatus: ReportStatusUIRepresentable {
    
    var status: ReportStatus {
        return self
    }
    
    var color: Color {
        switch self {
        case .notStarted, .notCreated, .notSent:
            return .gray
        case .inProgress, .sent, .done:
            return .black
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .notStarted, .inProgress:
            return true
        case .sent, .notCreated, .notSent, .done:
            return false
        }
    }
    
    var showTimer: Bool {
        return true // Всегда показываем таймер
    }
    
    var timerLabel: String {
        switch self {
        case .sent, .notCreated, .notSent:
            return "До старта"
        case .notStarted, .inProgress:
            return "До конца"
        case .done:
            return "Завершено"
        }
    }
    
    var timerValue: String {
        // Это будет вычисляться динамически
        return "00:00:00"
    }
    
    var progress: Double {
        switch self {
        case .sent, .notCreated, .notSent:
            return 0.0
        case .notStarted, .inProgress:
            return 0.5 // Будет вычисляться динамически
        case .done:
            return 1.0
        }
    }
}

/// Протокол для компонентов, которые могут обновлять статус
protocol ReportStatusUpdatable {
    func updateStatus(_ status: ReportStatus)
    func refreshStatus()
}

/// Протокол для компонентов, которые могут реагировать на изменения статуса
protocol ReportStatusObservable {
    func onStatusChanged(_ status: ReportStatus)
    func onPeriodChanged(isActive: Bool)
} 