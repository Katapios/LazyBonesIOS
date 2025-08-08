import Foundation
import UIKit

/// Модель данных для хранения настроек в UserDefaults
public struct SettingsDataModel: Codable {
    // Настройки уведомлений
    public var notificationsEnabled: Bool
    public var notificationMode: String
    public var notificationIntervalHours: Int
    public var notificationStartHour: Int
    public var notificationEndHour: Int
    
    // Настройки Telegram
    public var telegramToken: String?
    public var telegramChatId: String?
    public var telegramBotId: String?
    
    // Основные настройки
    public var deviceName: String
    public var isForceUnlockEnabled: Bool
    public var isBackgroundFetchTestEnabled: Bool
    
    // Статус отчета
    public var reportStatus: String
    
    // iCloud
    public var lastExportDate: Date?
    public var lastImportDate: Date?
    public var isICloudSyncEnabled: Bool
    
    // MARK: - Initialization
    
    public init(notificationsEnabled: Bool = false,
                notificationMode: String = "hourly",
                notificationIntervalHours: Int = 1,
                notificationStartHour: Int = 9,
                notificationEndHour: Int = 22,
                telegramToken: String? = nil,
                telegramChatId: String? = nil,
                telegramBotId: String? = nil,
                deviceName: String = UIDevice.current.name,
                isForceUnlockEnabled: Bool = false,
                isBackgroundFetchTestEnabled: Bool = false,
                reportStatus: String = "notStarted",
                lastExportDate: Date? = nil,
                lastImportDate: Date? = nil,
                isICloudSyncEnabled: Bool = false) {
        self.notificationsEnabled = notificationsEnabled
        self.notificationMode = notificationMode
        self.notificationIntervalHours = notificationIntervalHours
        self.notificationStartHour = notificationStartHour
        self.notificationEndHour = notificationEndHour
        self.telegramToken = telegramToken
        self.telegramChatId = telegramChatId
        self.telegramBotId = telegramBotId
        self.deviceName = deviceName
        self.isForceUnlockEnabled = isForceUnlockEnabled
        self.isBackgroundFetchTestEnabled = isBackgroundFetchTestEnabled
        self.reportStatus = reportStatus
        self.lastExportDate = lastExportDate
        self.lastImportDate = lastImportDate
        self.isICloudSyncEnabled = isICloudSyncEnabled
    }
    
    // MARK: - Mapping
    
    static func from(notificationSettings: NotificationSettings) -> SettingsDataModel {
        var model = SettingsDataModel()
        model.notificationsEnabled = notificationSettings.isEnabled
        model.notificationMode = notificationSettings.mode.rawValue
        model.notificationIntervalHours = notificationSettings.intervalHours
        model.notificationStartHour = notificationSettings.startHour
        model.notificationEndHour = notificationSettings.endHour
        return model
    }
    
    static func from(telegramSettings: TelegramSettings) -> SettingsDataModel {
        var model = SettingsDataModel()
        model.telegramToken = telegramSettings.token.isEmpty ? nil : telegramSettings.token
        model.telegramChatId = telegramSettings.chatId.isEmpty ? nil : telegramSettings.chatId
        model.telegramBotId = telegramSettings.botId
        return model
    }
    
    static func from(appSettings: AppSettings) -> SettingsDataModel {
        var model = SettingsDataModel()
        model.deviceName = appSettings.deviceName
        model.isForceUnlockEnabled = appSettings.isForceUnlockEnabled
        model.isBackgroundFetchTestEnabled = appSettings.isBackgroundFetchTestEnabled
        return model
    }
    
    func toNotificationSettings() -> NotificationSettings {
        return NotificationSettings(
            isEnabled: notificationsEnabled,
            mode: NotificationMode(rawValue: notificationMode) ?? .hourly,
            intervalHours: notificationIntervalHours,
            startHour: notificationStartHour,
            endHour: notificationEndHour
        )
    }
    
    func toTelegramSettings() -> TelegramSettings {
        return TelegramSettings(
            token: telegramToken ?? "",
            chatId: telegramChatId ?? "",
            botId: telegramBotId
        )
    }
    
    func toAppSettings() -> AppSettings {
        return AppSettings(
            deviceName: deviceName,
            isForceUnlockEnabled: isForceUnlockEnabled,
            isBackgroundFetchTestEnabled: isBackgroundFetchTestEnabled
        )
    }
    
    func toReportStatus() -> ReportStatus {
        return ReportStatus(rawValue: reportStatus) ?? .notStarted
    }
}
