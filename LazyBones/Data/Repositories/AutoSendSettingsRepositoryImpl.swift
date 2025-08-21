import Foundation

final class AutoSendSettingsRepositoryImpl: AutoSendSettingsRepository {
    private let ud: UserDefaultsManagerProtocol
    
    init(userDefaults: UserDefaultsManagerProtocol) {
        self.ud = userDefaults
    }
    
    func load() -> AutoSendSettings {
        let enabled = ud.bool(forKey: "autoSendToTelegram")
        let time = ud.get(Date.self, forKey: "autoSendTime")
            ?? Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())
            ?? Date()
        let lastStatus = ud.string(forKey: "lastAutoSendStatus")
        let lastDate = ud.get(Date.self, forKey: "lastAutoSendDate")
        return AutoSendSettings(enabled: enabled, time: time, lastStatus: lastStatus, lastDate: lastDate)
    }
    
    func save(_ settings: AutoSendSettings) {
        ud.set(settings.enabled, forKey: "autoSendToTelegram")
        ud.set(settings.time, forKey: "autoSendTime")
        ud.set(settings.lastStatus, forKey: "lastAutoSendStatus")
        ud.set(settings.lastDate, forKey: "lastAutoSendDate")
    }
}
