import Foundation

/// События для внешних отчетов из Telegram
enum ExternalReportsEvent {
    /// Загрузить отчеты
    case loadReports
    
    /// Обновить отчеты из Telegram
    case refreshFromTelegram
    
    /// Очистить историю
    case clearHistory
    
    /// Открыть группу в Telegram
    case openTelegramGroup
    
    /// Обработать сообщение из Telegram
    case handleTelegramMessage(TelegramMessage)
    
    /// Выбрать дату
    case selectDate(Date)
    
    /// Переключить режим выбора
    case toggleSelectionMode
    
    /// Выбрать отчет
    case selectReport(UUID)
    
    /// Выбрать все отчеты
    case selectAllReports
    
    /// Снять выбор со всех отчетов
    case deselectAllReports
    
    /// Удалить выбранные отчеты
    case deleteSelectedReports
    
    /// Очистить ошибку
    case clearError
    
    /// Сбросить lastUpdateId (для отладки)
    case resetLastUpdateId
} 