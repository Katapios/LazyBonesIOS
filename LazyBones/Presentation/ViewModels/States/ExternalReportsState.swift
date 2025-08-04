import Foundation

/// Состояние для внешних отчетов из Telegram
struct ExternalReportsState {
    /// Список внешних отчетов
    var reports: [DomainPost] = []
    
    /// Загрузка данных
    var isLoading = false
    
    /// Ошибка
    var error: Error? = nil
    
    /// Обновление из Telegram
    var isRefreshing = false
    
    /// Подключение к Telegram
    var telegramConnected = false
    
    /// Выбранная дата для фильтрации
    var selectedDate: Date = Date()
    
    /// Режим выбора отчетов
    var isSelectionMode = false
    
    /// Выбранные ID отчетов
    var selectedReportIDs: Set<UUID> = []
    
    /// Показывать ли пустое состояние
    var showEmptyState: Bool {
        return reports.isEmpty && !isLoading && !isRefreshing
    }
    
    /// Количество выбранных отчетов
    var selectedCount: Int {
        return selectedReportIDs.count
    }
    
    /// Все отчеты выбраны
    var allSelected: Bool {
        return !reports.isEmpty && selectedReportIDs.count == reports.count
    }
    
    /// Можно ли обновить из Telegram
    var canRefreshFromTelegram: Bool {
        return telegramConnected && !isRefreshing
    }
    
    /// Можно ли очистить историю
    var canClearHistory: Bool {
        return !reports.isEmpty && !isLoading
    }
} 