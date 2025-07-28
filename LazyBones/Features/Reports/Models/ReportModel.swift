import Foundation

// MARK: - Report Models

/// Модель отчёта пользователя
struct Report: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    var goodItems: [String]
    var badItems: [String]
    let published: Bool
    var voiceNotes: [VoiceNote]
    var type: ReportType
    var isEvaluated: Bool?
    var evaluationResults: [Bool]?
    
    // Telegram integration fields
    var authorUsername: String?
    var authorFirstName: String?
    var authorLastName: String?
    var isExternal: Bool?
    var externalVoiceNoteURLs: [URL]?
    var externalText: String?
    var externalMessageId: Int?
    var authorId: Int?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        goodItems: [String] = [],
        badItems: [String] = [],
        published: Bool = false,
        voiceNotes: [VoiceNote] = [],
        type: ReportType = .regular,
        isEvaluated: Bool? = nil,
        evaluationResults: [Bool]? = nil,
        authorUsername: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        isExternal: Bool? = nil,
        externalVoiceNoteURLs: [URL]? = nil,
        externalText: String? = nil,
        externalMessageId: Int? = nil,
        authorId: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.goodItems = goodItems
        self.badItems = badItems
        self.published = published
        self.voiceNotes = voiceNotes
        self.type = type
        self.isEvaluated = isEvaluated
        self.evaluationResults = evaluationResults
        self.authorUsername = authorUsername
        self.authorFirstName = authorFirstName
        self.authorLastName = authorLastName
        self.isExternal = isExternal
        self.externalVoiceNoteURLs = externalVoiceNoteURLs
        self.externalText = externalText
        self.externalMessageId = externalMessageId
        self.authorId = authorId
    }
}

/// Тип отчета
enum ReportType: String, Codable, CaseIterable {
    case regular = "regular"
    case custom = "custom"
    case external = "external"
    
    var displayName: String {
        switch self {
        case .regular:
            return "Обычный"
        case .custom:
            return "Кастомный"
        case .external:
            return "Внешний"
        }
    }
}

/// Статус отчёта
enum ReportStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case done = "done"
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Не начат"
        case .inProgress:
            return "В процессе"
        case .done:
            return "Завершен"
        }
    }
}

/// Модель для создания отчета
struct CreateReportRequest {
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [VoiceNote]
    let type: ReportType
    let evaluationResults: [Bool]?
}

/// Модель для обновления отчета
struct UpdateReportRequest {
    let id: UUID
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [VoiceNote]
    let type: ReportType
    let evaluationResults: [Bool]?
}

/// Модель для фильтрации отчетов
struct ReportFilter {
    let dateRange: DateRange?
    let type: ReportType?
    let status: ReportStatus?
    let isExternal: Bool?
    
    enum DateRange {
        case today
        case yesterday
        case thisWeek
        case thisMonth
        case custom(start: Date, end: Date)
    }
}

/// Модель для статистики отчетов
struct ReportStatistics {
    let totalReports: Int
    let publishedReports: Int
    let unpublishedReports: Int
    let averageGoodItems: Double
    let averageBadItems: Double
    let mostCommonGoodItems: [String]
    let mostCommonBadItems: [String]
    let reportsByType: [ReportType: Int]
    let reportsByStatus: [ReportStatus: Int]
} 