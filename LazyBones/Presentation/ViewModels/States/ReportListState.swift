import Foundation

/// Состояние списка отчетов
struct ReportListState {
    var reports: [DomainPost] = []
    var isLoading: Bool = false
    var error: Error? = nil
    var selectedDate: Date = Date()
    var filterType: PostType? = nil
    var showExternalReports: Bool = true
    
    var filteredReports: [DomainPost] {
        var filtered = reports
        
        // Фильтр по дате
        if !DateUtils.isToday(selectedDate) {
            filtered = filtered.filter { DateUtils.isSameDay($0.date, selectedDate) }
        }
        
        // Фильтр по типу
        if let filterType = filterType {
            filtered = filtered.filter { $0.type == filterType }
        }
        
        // Фильтр внешних отчетов
        if !showExternalReports {
            filtered = filtered.filter { !($0.isExternal ?? false) }
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    var hasReports: Bool {
        !filteredReports.isEmpty
    }
    
    var todayReports: [DomainPost] {
        reports.filter { DateUtils.isSameDay($0.date, Date()) }
    }
    
    var todayReportCount: Int {
        todayReports.count
    }
}

/// События списка отчетов
enum ReportListEvent {
    case loadReports
    case refreshReports
    case selectDate(Date)
    case filterByType(PostType?)
    case toggleExternalReports
    case deleteReport(DomainPost)
    case editReport(DomainPost)
} 