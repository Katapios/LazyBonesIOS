import Foundation
import UserNotifications

/// Сервис для управления уведомлениями отчетов
protocol PostNotificationServiceProtocol {
    /// Запланировать уведомления
    func scheduleNotifications()
    
    /// Отменить все уведомления
    func cancelAllNotifications()
    
    /// Отменить конкретное уведомление
    func cancelNotification(identifier: String)
    
    /// Получить все запланированные уведомления
    func getPendingNotifications() async -> [UNNotificationRequest]
    
    /// Получить все доставленные уведомления
    func getDeliveredNotifications() async -> [UNNotification]
}

class PostNotificationService: PostNotificationServiceProtocol {
    private let notificationService: NotificationServiceProtocol
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(notificationService: NotificationServiceProtocol, userDefaultsManager: UserDefaultsManagerProtocol) {
        self.notificationService = notificationService
        self.userDefaultsManager = userDefaultsManager
    }
    
    // MARK: - Public Methods
    
    func scheduleNotifications() {
        guard isNotificationsEnabled() else {
            Logger.info("Notifications disabled, skipping scheduling", log: Logger.notifications)
            return
        }
        
        Logger.info("Scheduling notifications", log: Logger.notifications)
        
        // Отменяем старые уведомления
        cancelAllNotifications()
        
        let startHour = getNotificationStartHour()
        let endHour = getNotificationEndHour()
        let reportStatus = getReportStatus()
        
        // Если отчет уже завершен, не планируем уведомления
        if reportStatus == .done {
            Logger.info("Report already done, no notifications needed", log: Logger.notifications)
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Планируем уведомления на сегодня
        scheduleNotificationsForDay(today, startHour: startHour, endHour: endHour)
        
        // Планируем уведомления на завтра
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        scheduleNotificationsForDay(tomorrow, startHour: startHour, endHour: endHour)
        
        Logger.info("Notifications scheduled successfully", log: Logger.notifications)
    }
    
    func cancelAllNotifications() {
        Logger.info("Cancelling all notifications", log: Logger.notifications)
        Task {
            try? await notificationService.cancelAllNotifications()
        }
    }
    
    func cancelNotification(identifier: String) {
        Logger.info("Cancelling notification: \(identifier)", log: Logger.notifications)
        Task {
            try? await notificationService.cancelNotification(identifier: identifier)
        }
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return (try? await notificationService.getPendingNotifications()) ?? []
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return (try? await notificationService.getDeliveredNotifications()) ?? []
    }
    
    // MARK: - Private Methods
    
    private func isNotificationsEnabled() -> Bool {
        return userDefaultsManager.bool(forKey: "notificationsEnabled")
    }
    
    private func getNotificationStartHour() -> Int {
        return userDefaultsManager.get(Int.self, forKey: "notificationStartHour", defaultValue: 8)
    }
    
    private func getNotificationEndHour() -> Int {
        return userDefaultsManager.get(Int.self, forKey: "notificationEndHour", defaultValue: 22)
    }
    
    private func getReportStatus() -> ReportStatus {
        let statusString = userDefaultsManager.string(forKey: "reportStatus") ?? "notStarted"
        return ReportStatus(rawValue: statusString) ?? .notStarted
    }
    
    private func scheduleNotificationsForDay(_ day: Date, startHour: Int, endHour: Int) {
        let calendar = Calendar.current
        
        // Уведомление о начале периода
        let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
        if startTime > Date() {
            scheduleNotification(
                title: "Время отчета",
                body: "Начинается период для отправки отчетов",
                date: startTime,
                identifier: "report_start_\(DateUtils.formatDate(day))"
            )
        }
        
        // Уведомление за 30 минут до конца
        let warningTime = calendar.date(bySettingHour: endHour, minute: 30, second: 0, of: day)!
        if warningTime > Date() {
            scheduleNotification(
                title: "Напоминание",
                body: "До конца периода отчетов осталось 30 минут",
                date: warningTime,
                identifier: "report_warning_\(DateUtils.formatDate(day))"
            )
        }
        
        // Уведомление о конце периода
        let endTime = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)!
        if endTime > Date() {
            scheduleNotification(
                title: "Период отчетов завершен",
                body: "Время для отправки отчетов истекло",
                date: endTime,
                identifier: "report_end_\(DateUtils.formatDate(day))"
            )
        }
    }
    
    private func scheduleNotification(title: String, body: String, date: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        Task {
            do {
                try await notificationService.scheduleNotification(title: title, body: body, date: date, identifier: identifier)
                Logger.info("Notification scheduled: \(identifier) for \(date)", log: Logger.notifications)
            } catch {
                Logger.error("Failed to schedule notification: \(error)", log: Logger.notifications)
            }
        }
    }
} 