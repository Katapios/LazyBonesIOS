import Foundation

/// Протокол репозитория для работы с отчетами
protocol PostRepositoryProtocol {
    func save(_ post: DomainPost) async throws
    func fetch() async throws -> [DomainPost]
    func fetch(for date: Date) async throws -> [DomainPost]
    func update(_ post: DomainPost) async throws
    func delete(_ post: DomainPost) async throws
    func clear() async throws
}

/// Протокол репозитория для работы с тегами
protocol TagRepositoryProtocol {
    func saveGoodTags(_ tags: [String]) async throws
    func saveBadTags(_ tags: [String]) async throws
    func loadGoodTags() async throws -> [String]
    func loadBadTags() async throws -> [String]
    func addGoodTag(_ tag: String) async throws
    func addBadTag(_ tag: String) async throws
    func removeGoodTag(_ tag: String) async throws
    func removeBadTag(_ tag: String) async throws
    func updateGoodTag(old: String, new: String) async throws
    func updateBadTag(old: String, new: String) async throws
}

/// Протокол репозитория для работы с настройками
protocol SettingsRepositoryProtocol {
    func saveNotificationSettings(
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    ) async throws
    
    func loadNotificationSettings() async throws -> (
        enabled: Bool,
        mode: NotificationMode,
        intervalHours: Int,
        startHour: Int,
        endHour: Int
    )
    
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async throws
    func loadTelegramSettings() async throws -> (token: String?, chatId: String?, botId: String?)
    
    func saveReportStatus(_ status: ReportStatus) async throws
    func loadReportStatus() async throws -> ReportStatus
    
    func saveForceUnlock(_ forceUnlock: Bool) async throws
    func loadForceUnlock() async throws -> Bool
} 