import Foundation
import UIKit

/// Реализация репозитория настроек, соответствующая SettingsRepositoryProtocol
public final class SettingsRepository: SettingsRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let localDataSource: SettingsLocalDataSourceProtocol
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    public init(
        localDataSource: SettingsLocalDataSourceProtocol = SettingsLocalDataSource(),
        fileManager: FileManager = .default
    ) {
        self.localDataSource = localDataSource
        self.fileManager = fileManager
    }
    
    // MARK: - Notification Settings
    
    public func getNotificationSettings() async throws -> NotificationSettings {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.toNotificationSettings()
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        var dataModel = try localDataSource.loadSettings()
        let updatedModel = SettingsDataModel.from(notificationSettings: settings)
        
        // Обновляем только необходимые поля
        dataModel.notificationsEnabled = updatedModel.notificationsEnabled
        dataModel.notificationMode = updatedModel.notificationMode
        dataModel.notificationIntervalHours = updatedModel.notificationIntervalHours
        dataModel.notificationStartHour = updatedModel.notificationStartHour
        dataModel.notificationEndHour = updatedModel.notificationEndHour
        
        try localDataSource.saveSettings(dataModel)
    }
    
    // MARK: - Telegram Settings
    
    public func getTelegramSettings() async throws -> TelegramSettings {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.toTelegramSettings()
    }
    
    public func updateTelegramSettings(_ settings: TelegramSettings) async throws {
        var dataModel = try localDataSource.loadSettings()
        let updatedModel = SettingsDataModel.from(telegramSettings: settings)
        
        // Обновляем только необходимые поля
        dataModel.telegramToken = updatedModel.telegramToken
        dataModel.telegramChatId = updatedModel.telegramChatId
        dataModel.telegramBotId = updatedModel.telegramBotId
        
        try localDataSource.saveSettings(dataModel)
    }
    
    // MARK: - App Settings
    
    public func getAppSettings() async throws -> AppSettings {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.toAppSettings()
    }
    
    public func updateAppSettings(_ settings: AppSettings) async throws {
        var dataModel = try localDataSource.loadSettings()
        let updatedModel = SettingsDataModel.from(appSettings: settings)
        
        // Обновляем только необходимые поля
        dataModel.deviceName = updatedModel.deviceName
        dataModel.isForceUnlockEnabled = updatedModel.isForceUnlockEnabled
        dataModel.isBackgroundFetchTestEnabled = updatedModel.isBackgroundFetchTestEnabled
        
        try localDataSource.saveSettings(dataModel)
    }
    
    // MARK: - Report Status
    
    public func getReportStatus() async throws -> ReportStatus {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.toReportStatus()
    }
    
    public func updateReportStatus(_ status: ReportStatus) async throws {
        var dataModel = try localDataSource.loadSettings()
        dataModel.reportStatus = status.rawValue
        try localDataSource.saveSettings(dataModel)
    }
    
    // MARK: - iCloud
    
    public func checkICloudStatus() async -> Bool {
        return fileManager.ubiquityIdentityToken != nil
    }
    
    public func exportToICloud() async throws -> URL {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw NSError(domain: "iCloud not available", code: -1)
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        let exportURL = documentsURL.appendingPathComponent("lazybones_backup_\(Date().timeIntervalSince1970).json")
        
        // Получаем текущие настройки
        let dataModel = try localDataSource.loadSettings()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(dataModel)
        try data.write(to: exportURL)
        
        // Обновляем дату последнего экспорта
        var updatedModel = dataModel
        updatedModel.lastExportDate = Date()
        try localDataSource.saveSettings(updatedModel)
        
        return exportURL
    }
    
    // MARK: - Force Unlock
    
    public func loadForceUnlock() async throws -> Bool {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.isForceUnlockEnabled
    }
    
    public func saveForceUnlock(_ forceUnlock: Bool) async throws {
        var dataModel = try localDataSource.loadSettings()
        dataModel.isForceUnlockEnabled = forceUnlock
        try localDataSource.saveSettings(dataModel)
    }
    
    // MARK: - Report Status (Legacy)
    
    public func loadReportStatus() async throws -> ReportStatus {
        let dataModel = try localDataSource.loadSettings()
        return dataModel.toReportStatus()
    }
    
    public func saveReportStatus(_ status: ReportStatus) async throws {
        var dataModel = try localDataSource.loadSettings()
        dataModel.reportStatus = status.rawValue
        try localDataSource.saveSettings(dataModel)
    }
} 