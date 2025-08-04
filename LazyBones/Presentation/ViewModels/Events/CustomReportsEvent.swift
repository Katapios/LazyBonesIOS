import Foundation

/// События для кастомных отчетов
enum CustomReportsEvent {
    case loadReports
    case refreshReports
    case createReport(goodItems: [String], badItems: [String])
    case evaluateReport(DomainPost, results: [Bool])
    case reEvaluateReport(DomainPost, results: [Bool])
    case deleteReport(DomainPost)
    case editReport(DomainPost)
    case selectDate(Date)
    case toggleSelectionMode
    case selectReport(UUID)
    case selectAllReports
    case deselectAllReports
    case deleteSelectedReports
    case clearError
} 