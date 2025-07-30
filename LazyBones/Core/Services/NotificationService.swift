import Foundation
import UserNotifications

/// Протокол сервиса уведомлений
protocol NotificationServiceProtocol {
    func requestPermission() async throws -> Bool
    func scheduleNotification(title: String, body: String, date: Date, identifier: String) async throws
    func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws
    func scheduleReportNotifications(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) async throws
    func cancelNotification(identifier: String) async throws
    func cancelAllNotifications() async throws
    func getPendingNotifications() async throws -> [UNNotificationRequest]
    func getDeliveredNotifications() async throws -> [UNNotification]
    func checkNotificationPermission() async -> Bool
    func getNotificationSettings() async -> UNNotificationSettings
    func debugNotificationStatus() async
}

/// Ошибки сервиса уведомлений
enum NotificationServiceError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed
    case cancellationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .cancellationFailed:
            return "Failed to cancel notification"
        case .unknown:
            return "Unknown error"
        }
    }
}

/// Реализация сервиса уведомлений
class NotificationService: NotificationServiceProtocol {
    
    private let notificationCenter: UNUserNotificationCenter
    
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - NotificationServiceProtocol
    
    func requestPermission() async throws -> Bool {
        Logger.debug("Requesting notification permission", log: Logger.ui)
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            Logger.info("Notification permission granted: \(granted)", log: Logger.ui)
            return granted
        } catch {
            Logger.error("Failed to request notification permission: \(error)", log: Logger.ui)
            throw NotificationServiceError.permissionDenied
        }
    }
    
    func scheduleNotification(title: String, body: String, date: Date, identifier: String) async throws {
        Logger.debug("Scheduling notification: \(identifier) for date: \(date)", log: Logger.ui)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            Logger.info("Notification scheduled successfully: \(identifier)", log: Logger.ui)
        } catch {
            Logger.error("Failed to schedule notification: \(error)", log: Logger.ui)
            throw NotificationServiceError.schedulingFailed
        }
    }
    
    func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws {
        Logger.debug("Scheduling repeating notification: \(identifier) at \(hour):\(minute)", log: Logger.ui)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Создаем компоненты даты для ежедневного повторения
        var triggerDate = DateComponents()
        triggerDate.hour = hour
        triggerDate.minute = minute
        
        // Проверяем, что время еще не прошло сегодня
        let calendar = Calendar.current
        let now = Date()
        var targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        
        // Если время уже прошло сегодня, планируем на завтра
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }
        
        // Создаем триггер для ежедневного повторения
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            Logger.info("Repeating notification scheduled successfully: \(identifier) for \(hour):\(minute) daily", log: Logger.ui)
        } catch {
            Logger.error("Failed to schedule repeating notification: \(error)", log: Logger.ui)
            throw NotificationServiceError.schedulingFailed
        }
    }
    
    func cancelNotification(identifier: String) async throws {
        Logger.debug("Cancelling notification: \(identifier)", log: Logger.ui)
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        Logger.info("Notification cancelled successfully: \(identifier)", log: Logger.ui)
    }
    
    func cancelAllNotifications() async throws {
        Logger.debug("Cancelling all notifications", log: Logger.ui)
        
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        Logger.info("All notifications cancelled successfully", log: Logger.ui)
    }
    
    func getPendingNotifications() async throws -> [UNNotificationRequest] {
        Logger.debug("Getting pending notifications", log: Logger.ui)
        
        let requests = await notificationCenter.pendingNotificationRequests()
        Logger.info("Found \(requests.count) pending notifications", log: Logger.ui)
        return requests
    }
    
    func getDeliveredNotifications() async throws -> [UNNotification] {
        Logger.debug("Getting delivered notifications", log: Logger.ui)
        
        let notifications = await notificationCenter.deliveredNotifications()
        Logger.info("Found \(notifications.count) delivered notifications", log: Logger.ui)
        return notifications
    }
    
    // MARK: - Helper Methods
    
    /// Запланировать уведомления для отчетов
    func scheduleReportNotifications(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) async throws {
        Logger.debug("Scheduling report notifications: enabled=\(enabled), interval=\(intervalHours), start=\(startHour), end=\(endHour), mode=\(mode)", log: Logger.ui)
        
        // Сначала отменяем все существующие уведомления
        try await cancelAllNotifications()
        
        guard enabled else {
            Logger.info("Notifications disabled, skipping scheduling", log: Logger.ui)
            return
        }
        
        let title = "LazyBones"
        let body = "Время для отчета! Как прошел ваш день?"
        
        switch mode {
        case "hourly":
            try await scheduleHourlyNotifications(title: title, body: body, startHour: startHour, endHour: endHour)
        case "twice":
            try await scheduleTwiceDailyNotifications(title: title, body: body, startHour: startHour, endHour: endHour)
        default:
            Logger.warning("Unknown notification mode: \(mode)", log: Logger.ui)
        }
    }
    
    private func scheduleHourlyNotifications(title: String, body: String, startHour: Int, endHour: Int) async throws {
        for hour in startHour...endHour {
            let identifier = "report_reminder_hourly_\(hour)"
            
            // Специальный текст для предостерегающего уведомления в 21:00
            let notificationBody = hour == 21 ? "Последний шанс отчитаться! Период отчетов скоро закончится." : body
            
            try await scheduleRepeatingNotification(
                title: title,
                body: notificationBody,
                hour: hour,
                minute: 0,
                identifier: identifier
            )
        }
    }
    
    private func scheduleTwiceDailyNotifications(title: String, body: String, startHour: Int, endHour: Int) async throws {
        let morningHour = startHour
        let eveningHour = 21 // Фиксированное время для вечернего уведомления
        
        // Утреннее уведомление
        let morningIdentifier = "report_reminder_morning"
        try await scheduleRepeatingNotification(
            title: title,
            body: body,
            hour: morningHour,
            minute: 0,
            identifier: morningIdentifier
        )
        
        // Вечернее уведомление (предостерегающее)
        let eveningIdentifier = "report_reminder_evening"
        let warningBody = "Последний шанс отчитаться! Период отчетов скоро закончится."
        try await scheduleRepeatingNotification(
            title: title,
            body: warningBody,
            hour: eveningHour,
            minute: 0,
            identifier: eveningIdentifier
        )
    }
    
    /// Проверить разрешения на уведомления
    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// Получить детальную информацию о разрешениях на уведомления
    func getNotificationSettings() async -> UNNotificationSettings {
        return await notificationCenter.notificationSettings()
    }
    
    /// Проверить и вывести статус уведомлений
    func debugNotificationStatus() async {
        Logger.info("=== DEBUG: Notification Status ===", log: Logger.ui)
        
        let settings = await getNotificationSettings()
        Logger.info("Authorization status: \(settings.authorizationStatus.rawValue)", log: Logger.ui)
        Logger.info("Alert setting: \(settings.alertSetting.rawValue)", log: Logger.ui)
        Logger.info("Sound setting: \(settings.soundSetting.rawValue)", log: Logger.ui)
        Logger.info("Badge setting: \(settings.badgeSetting.rawValue)", log: Logger.ui)
        
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        Logger.info("Pending notifications: \(pendingRequests.count)", log: Logger.ui)
        
        for request in pendingRequests {
            Logger.info("Pending: \(request.identifier)", log: Logger.ui)
        }
        
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        Logger.info("Delivered notifications: \(deliveredNotifications.count)", log: Logger.ui)
    }
} 