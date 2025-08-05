import Foundation
import SwiftUI

/// Состояние для главного экрана
struct MainState {
    /// Текущий статус отчета
    var reportStatus: ReportStatus = .notStarted
    
    /// Текущее время
    var currentTime: Date = Date()
    
    /// Время до следующего события
    var timeLeft: String = ""
    
    /// Прогресс времени (0.0 - 1.0)
    var timeProgress: Double = 0.0
    
    /// Подпись таймера
    var timerLabel: String = ""
    
    /// Только время (без подписи)
    var timerTimeTextOnly: String = ""
    
    /// Отчет за сегодня
    var todayReport: DomainPost?
    
    /// Количество хороших дел за сегодня
    var goodCountToday: Int = 0
    
    /// Количество плохих дел за сегодня
    var badCountToday: Int = 0
    
    /// Настройки уведомлений
    var notificationStartHour: Int = 8
    var notificationEndHour: Int = 22
    
    /// Текущий день
    var currentDay: Date = Date()
    
    /// Ошибка
    var error: Error? = nil
    
    /// Загрузка
    var isLoading: Bool = false
    
    // MARK: - Computed Properties
    
    /// Есть ли отчет за сегодня
    var hasReportForToday: Bool {
        return todayReport != nil
    }
    
    /// Можно ли редактировать отчет
    var canEditReport: Bool {
        return reportStatus == .notStarted || reportStatus == .inProgress
    }
    
    /// Заголовок кнопки
    var buttonTitle: String {
        return hasReportForToday ? "Редактировать отчёт" : "Создать отчёт"
    }
    
    /// Иконка кнопки
    var buttonIcon: String {
        return hasReportForToday ? "pencil.circle.fill" : "plus.circle.fill"
    }
    
    /// Цвет кнопки
    var buttonColor: Color {
        return (reportStatus == .sent || reportStatus == .notCreated || reportStatus == .notSent) ? .gray : .black
    }
    
    /// Текст статуса
    var reportStatusText: String {
        switch reportStatus {
        case .done: return "Отчёт отправлен"
        case .inProgress: return "Отчет заполняется..."
        case .notStarted: return "Заполни отчет!"
        case .notCreated: return "Отчёт не создан"
        case .notSent: return "Отчёт не отправлен"
        case .sent: return "Отчет отправлен"
        }
    }
    
    /// Цвет статуса
    var reportStatusColor: Color {
        switch reportStatus {
        case .done: return .black
        case .inProgress: return .black
        case .notStarted: return .gray
        case .notCreated: return .gray
        case .notSent: return .gray
        case .sent: return .black
        }
    }
    
    /// Активен ли период для создания отчетов
    var isReportPeriodActive: Bool {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        return now >= start && now < end
    }
}

/// События для главного экрана
enum MainEvent {
    /// Загрузить данные
    case loadData
    
    /// Обновить статус
    case updateStatus
    
    /// Проверить новый день
    case checkForNewDay
    
    /// Обновить время
    case updateTime
    
    /// Переключиться на вкладку планирования
    case switchToPlanning
    
    /// Очистить ошибку
    case clearError
} 