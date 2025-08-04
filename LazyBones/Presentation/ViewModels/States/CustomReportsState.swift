import Foundation

/// Состояние для кастомных отчетов
struct CustomReportsState {
    /// Список кастомных отчетов
    var reports: [DomainPost] = []
    var isLoading = false
    var error: Error? = nil
    var canCreateReport = true
    var canEvaluateReport = false
    var selectedDate: Date = Date()
    var isSelectionMode = false
    var selectedReportIDs: Set<UUID> = []
    var showEmptyState: Bool { return reports.isEmpty && !isLoading }
    var selectedCount: Int { return selectedReportIDs.count }
    var allSelected: Bool { return !reports.isEmpty && selectedReportIDs.count == reports.count }
    
    /// Отчеты, которые можно оценить (созданные сегодня и не оцененные)
    var evaluableReports: [DomainPost] {
        let today = Calendar.current.startOfDay(for: Date())
        return reports.filter { report in
            Calendar.current.isDate(report.date, inSameDayAs: today) && 
            report.isEvaluated != true
        }
    }
    
    /// Отчеты, которые уже оценены
    var evaluatedReports: [DomainPost] {
        return reports.filter { $0.isEvaluated == true }
    }
    
    /// Отчеты, которые можно переоценить (если включена настройка)
    var reEvaluableReports: [DomainPost] {
        let today = Calendar.current.startOfDay(for: Date())
        return reports.filter { report in
            Calendar.current.isDate(report.date, inSameDayAs: today) && 
            report.isEvaluated == true
        }
    }
} 