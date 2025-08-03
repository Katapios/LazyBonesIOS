import Foundation
import UIKit

/// Протокол для работы с UserDefaults
protocol UserDefaultsManagerProtocol {
    func set<T>(_ value: T, forKey key: String)
    func get<T>(_ type: T.Type, forKey key: String) -> T?
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T
    func remove(forKey key: String)
    func hasValue(forKey key: String) -> Bool
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func integer(forKey key: String) -> Int
    func data(forKey key: String) -> Data?
    func loadPosts() -> [Post]
    func savePosts(_ posts: [Post])
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?)
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?)
}

/// Менеджер для работы с UserDefaults
class UserDefaultsManager: UserDefaultsManagerProtocol {
    
    static let shared = UserDefaultsManager()
    
    private let userDefaults: UserDefaults
    private let appGroup = AppConfig.appGroup
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    }
    
    // MARK: - Generic Methods
    
    /// Сохранить значение
    func set<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    /// Получить значение
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        if let value = userDefaults.object(forKey: key) {
            if let typedValue = value as? T {
                return typedValue
            }
            // Специальная обработка для Int
            if T.self == Int.self, let intValue = value as? Int {
                return intValue as? T
            }
        }
        return nil
    }
    
    /// Получить значение с дефолтным значением
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T {
        if let value = userDefaults.object(forKey: key) {
            if let typedValue = value as? T {
                return typedValue
            }
            // Специальная обработка для Int
            if T.self == Int.self, let intValue = value as? Int {
                return intValue as! T
            }
        }
        return defaultValue
    }
    
    /// Удалить значение
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    /// Проверить существование ключа
    func hasValue(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    // MARK: - Specific Methods for App Settings
    
    /// Сохранить настройки Telegram
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        if let token = token {
            set(token, forKey: "telegramToken")
        } else {
            remove(forKey: "telegramToken")
        }
        
        if let chatId = chatId {
            set(chatId, forKey: "telegramChatId")
        } else {
            remove(forKey: "telegramChatId")
        }
        
        if let botId = botId {
            set(botId, forKey: "telegramBotId")
        } else {
            remove(forKey: "telegramBotId")
        }
    }
    
    /// Загрузить настройки Telegram
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        let token = get(String.self, forKey: "telegramToken")
        let chatId = get(String.self, forKey: "telegramChatId")
        let botId = get(String.self, forKey: "telegramBotId")
        return (token, chatId, botId)
    }
    
    /// Сохранить настройки автоотправки
    func saveAutoSendSettings(enabled: Bool, time: Date) {
        set(enabled, forKey: "autoSendToTelegram")
        set(time, forKey: "autoSendTime")
    }
    
    /// Загрузить настройки автоотправки
    func loadAutoSendSettings() -> (enabled: Bool, time: Date) {
        let enabled = get(Bool.self, forKey: "autoSendToTelegram", defaultValue: false)
        let time = get(Date.self, forKey: "autoSendTime") ?? Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        return (enabled, time)
    }
    
    /// Сохранить настройки уведомлений
    func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        set(enabled, forKey: "notificationsEnabled")
        set(intervalHours, forKey: "notificationIntervalHours")
        set(startHour, forKey: "notificationStartHour")
        set(endHour, forKey: "notificationEndHour")
        set(mode, forKey: "notificationMode")
    }
    
    /// Загрузить настройки уведомлений
    func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
        let enabled = get(Bool.self, forKey: "notificationsEnabled", defaultValue: false)
        let intervalHours = get(Int.self, forKey: "notificationIntervalHours", defaultValue: 1)
        let startHour = get(Int.self, forKey: "notificationStartHour", defaultValue: 8)
        let endHour = get(Int.self, forKey: "notificationEndHour", defaultValue: 22)
        let mode = get(String.self, forKey: "notificationMode", defaultValue: "hourly")
        return (enabled, intervalHours, startHour, endHour, mode)
    }
    
    /// Сохранить теги
    func saveTags(goodTags: [String], badTags: [String]) {
        set(goodTags, forKey: "goodTags")
        set(badTags, forKey: "badTags")
    }
    
    /// Загрузить теги
    func loadTags() -> (goodTags: [String], badTags: [String]) {
        let goodTags = get([String].self, forKey: "goodTags", defaultValue: [])
        let badTags = get([String].self, forKey: "badTags", defaultValue: [])
        return (goodTags, badTags)
    }
    
    /// Сохранить имя устройства
    func saveDeviceName(_ name: String) {
        set(name, forKey: "deviceName")
    }
    
    /// Загрузить имя устройства
    func loadDeviceName() -> String {
        return get(String.self, forKey: "deviceName", defaultValue: UIDevice.current.name)
    }
    
    /// Сохранить статус принудительной разблокировки
    func saveForceUnlock(_ forceUnlock: Bool) {
        set(forceUnlock, forKey: "forceUnlock")
    }
    
    /// Загрузить статус принудительной разблокировки
    func loadForceUnlock() -> Bool {
        return get(Bool.self, forKey: "forceUnlock", defaultValue: false)
    }
    
    /// Сохранить последнюю дату автоотправки
    func saveLastAutoSendDate(_ date: Date?) {
        set(date, forKey: "lastAutoSendDate")
    }
    
    /// Загрузить последнюю дату автоотправки
    func loadLastAutoSendDate() -> Date? {
        return get(Date.self, forKey: "lastAutoSendDate")
    }
    
    /// Сохранить последний статус автоотправки
    func saveLastAutoSendStatus(_ status: String?) {
        set(status, forKey: "lastAutoSendStatus")
    }
    
    /// Загрузить последний статус автоотправки
    func loadLastAutoSendStatus() -> String? {
        return get(String.self, forKey: "lastAutoSendStatus")
    }
    
    // MARK: - Protocol Methods
    
    func bool(forKey key: String) -> Bool {
        return get(Bool.self, forKey: key, defaultValue: false)
    }
    
    func string(forKey key: String) -> String? {
        return get(String.self, forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return get(Int.self, forKey: key, defaultValue: 0)
    }
    
    func integer(forKey key: String, defaultValue: Int) -> Int {
        return get(Int.self, forKey: key, defaultValue: defaultValue)
    }
    
    func data(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    func loadPosts() -> [Post] {
        guard let data = userDefaults.data(forKey: "posts") else { return [] }
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            return posts
        } catch {
            print("Error loading posts: \(error)")
            return []
        }
    }
    
    func savePosts(_ posts: [Post]) {
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults.set(data, forKey: "posts")
        } catch {
            print("Error saving posts: \(error)")
        }
    }
} 