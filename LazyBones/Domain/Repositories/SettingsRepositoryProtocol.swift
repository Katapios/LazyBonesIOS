import Foundation

/// Протокол для работы с настройками приложения
public protocol SettingsRepositoryProtocol {
    // MARK: - Настройки уведомлений
    
    /// Получить настройки уведомлений
    func getNotificationSettings() async throws -> NotificationSettings
    
    /// Обновить настройки уведомлений
    /// - Parameter settings: Новые настройки уведомлений
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    
    // MARK: - Настройки Telegram
    
    /// Получить настройки Telegram
    func getTelegramSettings() async throws -> TelegramSettings
    
    /// Обновить настройки Telegram
    /// - Parameter settings: Новые настройки Telegram
    func updateTelegramSettings(_ settings: TelegramSettings) async throws
    
    // MARK: - Основные настройки приложения
    
    /// Получить основные настройки приложения
    func getAppSettings() async throws -> AppSettings
    
    /// Обновить основные настройки приложения
    /// - Parameter settings: Новые основные настройки
    func updateAppSettings(_ settings: AppSettings) async throws
    
    // MARK: - Статус отчета
    
    /// Получить текущий статус отчета
    func getReportStatus() async throws -> ReportStatus
    
    /// Обновить статус отчета
    /// - Parameter status: Новый статус отчета
    func updateReportStatus(_ status: ReportStatus) async throws
    
    // MARK: - iCloud
    
    /// Проверить доступность iCloud
    func checkICloudStatus() async -> Bool
    
    /// Экспортировать данные в iCloud
    func exportToICloud() async throws -> URL
    
    // MARK: - Force Unlock
    
    /// Получить статус принудительной разблокировки
    func loadForceUnlock() async throws -> Bool
    
    /// Обновить статус принудительной разблокировки
    /// - Parameter forceUnlock: Новое значение принудительной разблокировки
    func saveForceUnlock(_ forceUnlock: Bool) async throws
    
    // MARK: - Report Status (Legacy)
    
    /// Получить текущий статус отчета (legacy)
    /// - Returns: Текущий статус отчета
    func loadReportStatus() async throws -> ReportStatus
    
    /// Обновить статус отчета (legacy)
    /// - Parameter status: Новый статус отчета
    func saveReportStatus(_ status: ReportStatus) async throws
}
