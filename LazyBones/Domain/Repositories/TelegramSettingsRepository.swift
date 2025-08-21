import Foundation

public protocol TelegramSettingsRepository {
    func load() -> TelegramSettings
    func save(_ settings: TelegramSettings)
    func loadLastUpdateId() -> Int?
    func saveLastUpdateId(_ id: Int)
    func resetLastUpdateId()
}
