import Foundation

/// Реализация репозитория настроек
class SettingsRepository: SettingsRepositoryProtocol {
    
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(userDefaultsManager: UserDefaultsManagerProtocol) {
        self.userDefaultsManager = userDefaultsManager
    }
    
    // MARK: - Notification Settings
    
    func saveNotificationSettings(
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    ) async throws {
        userDefaultsManager.set(enabled, forKey: "notificationsEnabled")
        userDefaultsManager.set(mode.rawValue, forKey: "notificationMode")
        userDefaultsManager.set(intervalHours, forKey: "notificationIntervalHours")
        userDefaultsManager.set(startHour, forKey: "notificationStartHour")
        userDefaultsManager.set(endHour, forKey: "notificationEndHour")
    }
    
    func loadNotificationSettings() async throws -> (
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    ) {
        let enabled = userDefaultsManager.bool(forKey: "notificationsEnabled")
        let modeRawValue = userDefaultsManager.string(forKey: "notificationMode") ?? "hourly"
        let mode = NotificationMode(rawValue: modeRawValue) ?? .hourly
        let intervalHours = userDefaultsManager.integer(forKey: "notificationIntervalHours")
        let startHour = userDefaultsManager.integer(forKey: "notificationStartHour")
        let endHour = userDefaultsManager.integer(forKey: "notificationEndHour")
        
        return (enabled, mode, intervalHours, startHour, endHour)
    }
    
    // MARK: - Telegram Settings
    
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws {
        userDefaultsManager.set(token, forKey: "telegramToken")
        userDefaultsManager.set(chatId, forKey: "telegramChatId")
        userDefaultsManager.set(botId, forKey: "telegramBotId")
    }
    
    func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?) {
        let token = userDefaultsManager.string(forKey: "telegramToken")
        let chatId = userDefaultsManager.string(forKey: "telegramChatId")
        let botId = userDefaultsManager.string(forKey: "telegramBotId")
        
        return (token, chatId, botId)
    }
    
    // MARK: - Report Status
    
    func saveReportStatus(_ status: ReportStatus) async throws {
        userDefaultsManager.set(status.rawValue, forKey: "reportStatus")
    }
    
    func loadReportStatus() async throws -> ReportStatus {
        let statusRawValue = userDefaultsManager.string(forKey: "reportStatus") ?? "notStarted"
        return ReportStatus(rawValue: statusRawValue) ?? .notStarted
    }
    
    // MARK: - Force Unlock
    
    func saveForceUnlock(_ forceUnlock: Bool) async throws {
        userDefaultsManager.set(forceUnlock, forKey: "forceUnlock")
    }
    
    func loadForceUnlock() async throws -> Bool {
        return userDefaultsManager.bool(forKey: "forceUnlock")
    }
} 