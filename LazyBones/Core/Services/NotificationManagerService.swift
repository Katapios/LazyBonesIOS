import Foundation
import UserNotifications
import Combine

/// Typealias для решения проблемы с any протоколами
typealias NotificationManagerServiceType = any NotificationManagerServiceProtocol

/// Протокол для управления уведомлениями
protocol NotificationManagerServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    var notificationsEnabled: Bool { get set }
    var notificationIntervalHours: Int { get set }
    var notificationStartHour: Int { get set }
    var notificationEndHour: Int { get set }
    var notificationMode: NotificationMode { get set }
    
    // MARK: - Settings Management
    func saveNotificationSettings()
    func loadNotificationSettings()
    
    // MARK: - Notification Logic
    func requestNotificationPermissionAndSchedule()
    func scheduleNotifications()
    func cancelAllNotifications()
    func scheduleNotificationsIfNeeded()
    
    // MARK: - Helper Methods
    func notificationScheduleForToday() -> String?
}

/// Сервис для управления уведомлениями
class NotificationManagerService: NotificationManagerServiceProtocol {
    
    // MARK: - Published Properties
    @Published var notificationsEnabled: Bool = false {
        didSet { 
            saveNotificationSettings()
            if notificationsEnabled { 
                requestNotificationPermissionAndSchedule() 
            } else { 
                cancelAllNotifications() 
            }
        }
    }
    
    @Published var notificationIntervalHours: Int = 1 { // 1-12
        didSet { 
            saveNotificationSettings()
            if notificationsEnabled { 
                scheduleNotifications() 
            }
        }
    }
    
    @Published var notificationStartHour: Int = 8
    @Published var notificationEndHour: Int = 22
    
    @Published var notificationMode: NotificationMode = .hourly {
        didSet { 
            saveNotificationSettings()
            if notificationsEnabled { 
                scheduleNotifications() 
            }
        }
    }
    
    // MARK: - Dependencies
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let notificationService: NotificationServiceProtocol
    
    // MARK: - Private Properties
    private let appGroup = AppConfig.appGroup
    private var isScheduling = false
    private var lastScheduleAt: Date = .distantPast
    
    // MARK: - Initialization
    init(
        userDefaultsManager: UserDefaultsManagerProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.notificationService = notificationService
        
        loadNotificationSettings()
    }
    
    // MARK: - Settings Management
    
    func saveNotificationSettings() {
        userDefaultsManager.saveNotificationSettings(
            enabled: notificationsEnabled,
            intervalHours: notificationIntervalHours,
            startHour: notificationStartHour,
            endHour: notificationEndHour,
            mode: notificationMode.rawValue
        )
    }
    
    func loadNotificationSettings() {
        let settings = userDefaultsManager.loadNotificationSettings()
        notificationsEnabled = settings.enabled
        notificationMode = NotificationMode(rawValue: settings.mode) ?? .hourly
        notificationIntervalHours = settings.intervalHours
        notificationStartHour = settings.startHour
        notificationEndHour = settings.endHour
    }
    
    // MARK: - Notification Logic
    
    func requestNotificationPermissionAndSchedule() {
        Task {
            do {
                let granted = try await notificationService.requestPermission()
                await MainActor.run {
                    if granted { 
                        self.scheduleNotifications() 
                    } else { 
                        self.notificationsEnabled = false 
                    }
                }
            } catch {
                await MainActor.run {
                    self.notificationsEnabled = false
                }
                Logger.error("Failed to request notification permission: \(error)", log: Logger.notifications)
            }
        }
    }
    
    func scheduleNotifications() {
        guard notificationsEnabled else {
            Logger.debug("Notifications disabled, skipping scheduling", log: Logger.notifications)
            return
        }

        // Простая защита от бурстов повторных вызовов
        let now = Date()
        if isScheduling || now.timeIntervalSince(lastScheduleAt) < 2 { // 2 сек debounce
            Logger.debug("scheduleNotifications skipped (debounced)", log: Logger.notifications)
            return
        }
        isScheduling = true
        lastScheduleAt = now

        Logger.debug("Scheduling notifications", log: Logger.notifications)
        
        Task {
            do {
                // Проверяем разрешения на уведомления
                let hasPermission = await notificationService.checkNotificationPermission()
                guard hasPermission else {
                    Logger.debug("No notification permission, skipping scheduling", log: Logger.notifications)
                    await MainActor.run {
                        self.notificationsEnabled = false
                    }
                    self.isScheduling = false
                    return
                }
                
                // Сначала выводим debug информацию
                await notificationService.debugNotificationStatus()
                
                // Используем правильную логику из NotificationService (он уже выполняет отмену существующих уведомлений)
                try await notificationService.scheduleReportNotifications(
                    enabled: true,
                    intervalHours: notificationIntervalHours,
                    startHour: notificationStartHour,
                    endHour: notificationEndHour,
                    mode: notificationMode.rawValue
                )
                Logger.debug("Notifications scheduled successfully with mode: \(notificationMode.rawValue)", log: Logger.notifications)
                
                // Выводим debug информацию после планирования
                await notificationService.debugNotificationStatus()
            } catch {
                Logger.error("Failed to schedule notifications: \(error)", log: Logger.notifications)
            }
            self.isScheduling = false
        }
    }
    
    func cancelAllNotifications() {
        Logger.debug("Cancelling all notifications", log: Logger.notifications)
        Task {
            try? await notificationService.cancelAllNotifications()
        }
    }
    
    func scheduleNotificationsIfNeeded() {
        guard notificationsEnabled else { return }
        scheduleNotifications()
    }
    
    // MARK: - Helper Methods
    
    func notificationScheduleForToday() -> String? {
        guard notificationsEnabled else { return nil }
        
        let startHour = notificationStartHour
        let endHour = notificationEndHour
        
        switch notificationMode {
        case .hourly:
            return "Каждый час с \(startHour):00 до \(endHour):00"
        case .twice:
            let interval = notificationIntervalHours
                    return "Каждые \(interval) часа с \(startHour):00 до \(endHour):00"
    }
}
} 