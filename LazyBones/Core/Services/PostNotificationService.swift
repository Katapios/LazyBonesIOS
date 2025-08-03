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
    
    /// Запланировать уведомления при необходимости
    func scheduleNotificationsIfNeeded()
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
        let notificationMode = getNotificationMode()
        let reportStatus = getReportStatus()
        
        // Если отчет уже завершен, не планируем уведомления
        if reportStatus == .done {
            Logger.info("Report already done, no notifications needed", log: Logger.notifications)
            return
        }
        
        Task {
            do {
                // Сначала выводим debug информацию
                await notificationService.debugNotificationStatus()
                
                // Используем правильную логику из NotificationService
                let intervalHours = getNotificationIntervalHours()
                try await notificationService.scheduleReportNotifications(
                    enabled: true,
                    intervalHours: intervalHours,
                    startHour: startHour,
                    endHour: endHour,
                    mode: notificationMode
                )
                Logger.info("Notifications scheduled successfully with mode: \(notificationMode)", log: Logger.notifications)
                
                // Выводим debug информацию после планирования
                await notificationService.debugNotificationStatus()
            } catch {
                Logger.error("Failed to schedule notifications: \(error)", log: Logger.notifications)
            }
        }
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
    
    private func getNotificationMode() -> String {
        let modeString = userDefaultsManager.string(forKey: "notificationMode") ?? "hourly"
        Logger.info("Notification mode loaded: \(modeString)", log: Logger.notifications)
        return modeString
    }
    
    private func getNotificationIntervalHours() -> Int {
        return userDefaultsManager.get(Int.self, forKey: "notificationIntervalHours", defaultValue: 1)
    }
    
    private func getReportStatus() -> ReportStatus {
        let statusString = userDefaultsManager.string(forKey: "reportStatus") ?? "notStarted"
        return ReportStatus(rawValue: statusString) ?? .notStarted
    }
    
    func scheduleNotificationsIfNeeded() {
        guard isNotificationsEnabled() else { return }
        scheduleNotifications()
    }
} 