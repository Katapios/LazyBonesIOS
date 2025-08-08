import Foundation
import UIKit

/// Менеджер миграции настроек со старого формата на новый
public final class SettingsMigrationManager {
    
    // MARK: - Dependencies
    
    private let oldUserDefaults: UserDefaults
    private let settingsRepository: SettingsRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(
        oldUserDefaults: UserDefaults = .standard,
        settingsRepository: SettingsRepositoryProtocol = SettingsRepositoryFactory.makeSettingsRepository()
    ) {
        self.oldUserDefaults = oldUserDefaults
        self.settingsRepository = settingsRepository
    }
    
    // MARK: - Public Methods
    
    /// Проверяет, требуется ли миграция
    public func isMigrationNeeded() async -> Bool {
        // Проверяем, есть ли старые настройки
        let hasOldSettings = oldUserDefaults.object(forKey: "notificationsEnabled") != nil ||
                            oldUserDefaults.object(forKey: "telegramToken") != nil ||
                            oldUserDefaults.object(forKey: "reportStatus") != nil
        
        // Если есть старые настройки, проверяем, не была ли уже выполнена миграция
        if hasOldSettings {
            do {
                let settings = try await settingsRepository.getNotificationSettings()
                // Если настройки по умолчанию, возможно, миграция еще не выполнялась
                return settings == NotificationSettings()
            } catch {
                // В случае ошибки считаем, что миграция нужна
                return true
            }
        }
        
        return false
    }
    
    /// Выполняет миграцию настроек со старого формата на новый
    public func migrateIfNeeded() async throws {
        guard await isMigrationNeeded() else {
            return
        }
        
        // Мигрируем настройки уведомлений
        if oldUserDefaults.object(forKey: "notificationsEnabled") != nil {
            let enabled = oldUserDefaults.bool(forKey: "notificationsEnabled")
            let modeRawValue = oldUserDefaults.string(forKey: "notificationMode") ?? "hourly"
            let mode = NotificationMode(rawValue: modeRawValue) ?? .hourly
            let intervalHours = oldUserDefaults.integer(forKey: "notificationIntervalHours")
            let startHour = oldUserDefaults.integer(forKey: "notificationStartHour")
            let endHour = oldUserDefaults.integer(forKey: "notificationEndHour")
            
            let settings = NotificationSettings(
                isEnabled: enabled,
                mode: mode,
                intervalHours: intervalHours > 0 ? intervalHours : 1,
                startHour: startHour > 0 ? startHour : 9,
                endHour: endHour > 0 ? endHour : 22
            )
            
            try await settingsRepository.updateNotificationSettings(settings)
        }
        
        // Мигрируем настройки Telegram
        if oldUserDefaults.object(forKey: "telegramToken") != nil || 
           oldUserDefaults.object(forKey: "telegramChatId") != nil ||
           oldUserDefaults.object(forKey: "telegramBotId") != nil {
            
            let token = oldUserDefaults.string(forKey: "telegramToken") ?? ""
            let chatId = oldUserDefaults.string(forKey: "telegramChatId") ?? ""
            let botId = oldUserDefaults.string(forKey: "telegramBotId")
            
            let settings = TelegramSettings(
                token: token,
                chatId: chatId,
                botId: botId
            )
            
            try await settingsRepository.updateTelegramSettings(settings)
        }
        
        // Мигрируем статус отчета
        if oldUserDefaults.object(forKey: "reportStatus") != nil {
            let statusRawValue = oldUserDefaults.string(forKey: "reportStatus") ?? "notStarted"
            let status = ReportStatus(rawValue: statusRawValue) ?? .notStarted
            try await settingsRepository.updateReportStatus(status)
        }
        
        // Мигрируем настройки приложения
        var deviceName = await getDeviceName()
        if let savedDeviceName = oldUserDefaults.string(forKey: "deviceName"), !savedDeviceName.isEmpty {
            deviceName = savedDeviceName
        }
        
        let isForceUnlockEnabled = oldUserDefaults.object(forKey: "forceUnlock") as? Bool ?? false
        let isBackgroundFetchTestEnabled = oldUserDefaults.object(forKey: "backgroundFetchTestEnabled") as? Bool ?? false
        
        let appSettings = AppSettings(
            deviceName: deviceName,
            isForceUnlockEnabled: isForceUnlockEnabled,
            isBackgroundFetchTestEnabled: isBackgroundFetchTestEnabled
        )
        
        try await settingsRepository.updateAppSettings(appSettings)
        
        // После успешной миграции помечаем старые настройки для удаления
        // (удаляем в следующем запуске, чтобы не потерять данные при ошибке)
        UserDefaults.standard.set(true, forKey: "shouldCleanupOldSettings")
        
        // Очищаем старые настройки
        await cleanupOldSettingsIfNeeded()
    }
    
    /// Получает имя устройства
    private func getDeviceName() async -> String {
        return await UIDevice.current.name
    }
    
    /// Очищает старые настройки, если миграция была выполнена успешно
    public func cleanupOldSettingsIfNeeded() async {
        guard UserDefaults.standard.bool(forKey: "shouldCleanupOldSettings") else {
            return
        }
        
        // Удаляем старые ключи
        let keysToRemove = [
            "notificationsEnabled", "notificationMode", "notificationIntervalHours",
            "notificationStartHour", "notificationEndHour", "telegramToken",
            "telegramChatId", "telegramBotId", "reportStatus", "deviceName",
            "forceUnlock", "backgroundFetchTestEnabled", "shouldCleanupOldSettings"
        ]
        
        for key in keysToRemove {
            oldUserDefaults.removeObject(forKey: key)
        }
        
        oldUserDefaults.synchronize()
    }
}
