import Foundation

/// Domain Entity - Статус отчета
enum ReportStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case sent = "sent"
    case notCreated = "notCreated"
    case notSent = "notSent"
    
    // MARK: - Legacy Support (deprecated)
    @available(*, deprecated, renamed: "sent", message: "Use .sent instead of .done")
    static let done: ReportStatus = .sent
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Заполни отчет"
        case .inProgress:
            return "Отчет заполняется..."
        case .sent:
            return "Отчет отправлен"
        case .notCreated:
            return "Отчёт не создан"
        case .notSent:
            return "Отчёт не отправлен"
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