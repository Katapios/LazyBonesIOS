import Foundation
import SwiftUI

/// Состояние главного экрана
struct MainState {
    // MARK: - Report Status
    var reportStatus: ReportStatus = .notStarted
    var isReportPeriodActive: Bool = false
    var currentTime: Date = Date()
    
    // MARK: - Today's Report
    var hasReportForToday: Bool = false
    var canEditReport: Bool = true
    
    // MARK: - Progress Counters
    var goodCountToday: Int = 0
    var badCountToday: Int = 0
    
    // MARK: - Timer
    var timeLeft: String = ""
    var timerLabel: String = "До старта"
    var timerProgress: Double = 0.0
    
    // MARK: - Button State
    var buttonTitle: String = "Создать отчёт"
    var buttonIcon: String = "plus.circle.fill"
    var buttonColor: Color = .black
    
    // MARK: - Settings
    var notificationStartHour: Int = 8
    var notificationEndHour: Int = 22
    var currentDay: Date = Calendar.current.startOfDay(for: Date())
    
    // MARK: - Computed Properties
    
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
    
    var timerTimeTextOnly: String {
        let value = timeLeft
        if let range = value.range(of: ": ") {
            return String(value[range.upperBound...])
        }
        return value
    }
    
    var timerTimeTextOnlyForStatus: String {
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
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(currentDay, inSameDayAs: today) {
            return "00:00:00"
        }
        
        if reportStatus == .sent || reportStatus == .notCreated || reportStatus == .notSent {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            return "00:00:00"
        }
    }
}

/// События главного экрана
enum MainEvent {
    case loadTodayReport
    case updateStatus
    case checkForNewDay
    case updateTimer
    case switchToPlanningTab
} 