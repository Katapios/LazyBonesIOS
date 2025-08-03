import Foundation

/// Domain Entity - Статус отчета
enum ReportStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case done = "done"
    case notCreated = "notCreated"
    case notSent = "notSent"
    case sent = "sent"
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Заполни отчет"
        case .inProgress:
            return "Отчет заполняется..."
        case .done:
            return "Завершен"
        case .notCreated:
            return "Отчёт не создан"
        case .notSent:
            return "Отчёт не отправлен"
        case .sent:
            return "Отчет отправлен"
        }
    }
}

/// Режим уведомлений
enum NotificationMode: String, Codable, CaseIterable {
    case hourly
    case twice
    
    var description: String {
        switch self {
        case .hourly: return "Каждый час"
        case .twice: return "2 раза в день"
        }
    }
} 