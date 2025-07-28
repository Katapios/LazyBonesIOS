import Foundation
import UserNotifications

/// Протокол сервиса уведомлений
protocol NotificationServiceProtocol {
    func requestPermission() async throws -> Bool
    func scheduleNotification(title: String, body: String, date: Date, identifier: String) async throws
    func scheduleRepeatingNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) async throws
    func cancelNotification(identifier: String) async throws
    func cancelAllNotifications() async throws
    func getPendingNotifications() async throws -> [UNNotificationRequest]
    func getDeliveredNotifications() async throws -> [UNNotification]
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
        
        var triggerDate = DateComponents()
        triggerDate.hour = hour
        triggerDate.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            Logger.info("Repeating notification scheduled successfully: \(identifier)", log: Logger.ui)
        } catch {
            Logger.error("Failed to schedule repeating notification: \(error)", log: Logger.ui)
            throw NotificationServiceError.schedulingFailed
        }
    }
    
    func cancelNotification(identifier: String) async throws {
        Logger.debug("Cancelling notification: \(identifier)", log: Logger.ui)
        
        do {
            await notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            Logger.info("Notification cancelled successfully: \(identifier)", log: Logger.ui)
        } catch {
            Logger.error("Failed to cancel notification: \(error)", log: Logger.ui)
            throw NotificationServiceError.cancellationFailed
        }
    }
    
    func cancelAllNotifications() async throws {
        Logger.debug("Cancelling all notifications", log: Logger.ui)
        
        do {
            await notificationCenter.removeAllPendingNotificationRequests()
            await notificationCenter.removeAllDeliveredNotifications()
            Logger.info("All notifications cancelled successfully", log: Logger.ui)
        } catch {
            Logger.error("Failed to cancel all notifications: \(error)", log: Logger.ui)
            throw NotificationServiceError.cancellationFailed
        }
    }
    
    func getPendingNotifications() async throws -> [UNNotificationRequest] {
        Logger.debug("Getting pending notifications", log: Logger.ui)
        
        do {
            let requests = await notificationCenter.pendingNotificationRequests()
            Logger.info("Found \(requests.count) pending notifications", log: Logger.ui)
            return requests
        } catch {
            Logger.error("Failed to get pending notifications: \(error)", log: Logger.ui)
            throw NotificationServiceError.unknown
        }
    }
    
    func getDeliveredNotifications() async throws -> [UNNotification] {
        Logger.debug("Getting delivered notifications", log: Logger.ui)
        
        do {
            let notifications = await notificationCenter.deliveredNotifications()
            Logger.info("Found \(notifications.count) delivered notifications", log: Logger.ui)
            return notifications
        } catch {
            Logger.error("Failed to get delivered notifications: \(error)", log: Logger.ui)
            throw NotificationServiceError.unknown
        }
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
            try await scheduleRepeatingNotification(
                title: title,
                body: body,
                hour: hour,
                minute: 0,
                identifier: identifier
            )
        }
    }
    
    private func scheduleTwiceDailyNotifications(title: String, body: String, startHour: Int, endHour: Int) async throws {
        let morningHour = startHour
        let eveningHour = endHour - 2 // За 2 часа до конца дня
        
        // Утреннее уведомление
        let morningIdentifier = "report_reminder_morning"
        try await scheduleRepeatingNotification(
            title: title,
            body: body,
            hour: morningHour,
            minute: 0,
            identifier: morningIdentifier
        )
        
        // Вечернее уведомление
        let eveningIdentifier = "report_reminder_evening"
        try await scheduleRepeatingNotification(
            title: title,
            body: body,
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
} 