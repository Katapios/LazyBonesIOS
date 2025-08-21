import Foundation

public protocol AutoSendSettingsRepository {
    func load() -> AutoSendSettings
    func save(_ settings: AutoSendSettings)
}
