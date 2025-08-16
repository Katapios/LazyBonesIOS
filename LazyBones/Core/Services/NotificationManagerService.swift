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
            // Suppress side effects during bootstrap and ignore redundant sets
            guard !isBootstrapping, oldValue != notificationsEnabled else { return }
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
            guard !isBootstrapping, oldValue != notificationIntervalHours else { return }
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
            guard !isBootstrapping, oldValue != notificationMode else { return }
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
    private var isBootstrapping = false
    
    // MARK: - Initialization
    init(
        userDefaultsManager: UserDefaultsManagerProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.notificationService = notificationService
        // Suppress side effects while loading persisted settings
        isBootstrapping = true
        loadNotificationSettings()
        isBootstrapping = false
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
                        if self.notificationsEnabled { self.notificationsEnabled = false }
                    }
                }
            } catch {
                await MainActor.run {
                    if self.notificationsEnabled { self.notificationsEnabled = false }
                }
                Logger.error("Failed to request notification permission: \(error)", log: Logger.notifications)
            }
        }
    }
    
    func scheduleNotifications() {
        guard notificationsEnabled else {
            Logger.info("Notifications disabled, skipping scheduling", log: Logger.notifications)
            return
        }
        
        Logger.info("Scheduling notifications", log: Logger.notifications)
        
        // Отменяем старые уведомления
        cancelAllNotifications()
        
        Task {
            do {
                // Проверяем разрешения на уведомления
                let hasPermission = await notificationService.checkNotificationPermission()
                guard hasPermission else {
                    Logger.warning("No notification permission, skipping scheduling", log: Logger.notifications)
                    await MainActor.run {
                        if self.notificationsEnabled { self.notificationsEnabled = false }
                    }
                    return
                }
                
                // Сначала выводим debug информацию
                await notificationService.debugNotificationStatus()
                
                // Используем правильную логику из NotificationService
                try await notificationService.scheduleReportNotifications(
                    enabled: true,
                    intervalHours: notificationIntervalHours,
                    startHour: notificationStartHour,
                    endHour: notificationEndHour,
                    mode: notificationMode.rawValue
                )
                Logger.info("Notifications scheduled successfully with mode: \(notificationMode.rawValue)", log: Logger.notifications)
                
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