import Foundation

/// События для обычных отчетов
enum RegularReportsEvent {
    /// Загрузить отчеты
    case loadReports
    
    /// Обновить отчеты
    case refreshReports
    
    /// Создать новый отчет
    case createReport(goodItems: [String], badItems: [String])
    
    /// Отправить отчет
    case sendReport(DomainPost)
    
    /// Удалить отчет
    case deleteReport(DomainPost)
    
    /// Редактировать отчет
    case editReport(DomainPost)
    
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
} 