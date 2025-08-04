import Foundation

/// Состояние для обычных отчетов
struct RegularReportsState {
    /// Список обычных отчетов
    var reports: [DomainPost] = []
    
    /// Загрузка данных
    var isLoading = false
    
    /// Ошибка
    var error: Error? = nil
    
    /// Можно ли создать новый отчет
    var canCreateReport = true
    
    /// Можно ли отправить отчет
    var canSendReport = false
    
    /// Выбранная дата для фильтрации
    var selectedDate: Date = Date()
    
    /// Режим выбора отчетов
    var isSelectionMode = false
    
    /// Выбранные ID отчетов
    var selectedReportIDs: Set<UUID> = []
    
    /// Показывать ли пустое состояние
    var showEmptyState: Bool {
        return reports.isEmpty && !isLoading
    }
    
    /// Количество выбранных отчетов
    var selectedCount: Int {
        return selectedReportIDs.count
    }
    
    /// Все отчеты выбраны
    var allSelected: Bool {
        return !reports.isEmpty && selectedReportIDs.count == reports.count
    }
} 