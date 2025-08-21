import Foundation

final class TelegramSettingsRepositoryImpl: TelegramSettingsRepository {
    private let ud: UserDefaultsManagerProtocol
    
    init(userDefaults: UserDefaultsManagerProtocol) {
        self.ud = userDefaults
    }
    
    func load() -> TelegramSettings {
        let token = ud.string(forKey: "telegramToken")
        let chatId = ud.string(forKey: "telegramChatId")
        let botId = ud.string(forKey: "telegramBotId")
        let intVal = ud.integer(forKey: "lastUpdateId")
        let lastUpdateId = ud.hasValue(forKey: "lastUpdateId") ? intVal : nil
        return TelegramSettings(token: token, chatId: chatId, botId: botId, lastUpdateId: lastUpdateId)
    }
    
    func save(_ settings: TelegramSettings) {
        // Используем специализированный метод для консистентности с текущими тестами/моками
        ud.saveTelegramSettings(token: settings.token, chatId: settings.chatId, botId: settings.botId)
        if let lastId = settings.lastUpdateId {
            ud.set(lastId, forKey: "lastUpdateId")
        }
    }
    
    func loadLastUpdateId() -> Int? {
        let intVal = ud.integer(forKey: "lastUpdateId")
        return ud.hasValue(forKey: "lastUpdateId") ? intVal : nil
    }
    
    func saveLastUpdateId(_ id: Int) {
        ud.set(id, forKey: "lastUpdateId")
    }
    
    func resetLastUpdateId() {
        ud.remove(forKey: "lastUpdateId")
    }
}
