import Foundation
import WidgetKit

class LocalReportService {
    static let shared = LocalReportService()
    private let userDefaults: UserDefaults?
    private let key = "posts"
    private let reportStatusKey = "reportStatus"
    private let forceUnlockKey = "forceUnlock"
    private let goodTagsKey = "goodTags"
    private let badTagsKey = "badTags"
    private let defaultGoodTags = ["Здоровье", "Работа", "Учёба", "Спорт", "Сон", "Питание", "Отдых", "Чтение", "Творчество", "Общение"]
    private let defaultBadTags = ["Прокрастинация", "Переедание", "Мало сна", "Стресс", "Лень", "Зависимость", "Скандал", "Трата времени"]
    
    private init() {
        userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        migrateOldTagsIfNeeded()
    }
    
    func loadPosts() -> [Post] {
        guard let data = userDefaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
    
    func savePosts(_ posts: [Post]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        userDefaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func clearPosts() {
        userDefaults?.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getReportStatus() -> ReportStatus {
        if let raw = userDefaults?.string(forKey: reportStatusKey), let status = ReportStatus(rawValue: raw) {
            return status
        }
        return .notStarted
    }
    func saveReportStatus(_ status: ReportStatus) {
        userDefaults?.set(status.rawValue, forKey: reportStatusKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func getForceUnlock() -> Bool {
        userDefaults?.bool(forKey: forceUnlockKey) ?? false
    }
    func saveForceUnlock(_ value: Bool) {
        userDefaults?.set(value, forKey: forceUnlockKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Good Tags
    func loadGoodTags() -> [String] {
        if let data = userDefaults?.data(forKey: goodTagsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data), !decoded.isEmpty {
            return decoded
        }
        return defaultGoodTags
    }
    func saveGoodTags(_ tags: [String]) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        userDefaults?.set(data, forKey: goodTagsKey)
    }
    func addGoodTag(_ tag: String) {
        var tags = loadGoodTags()
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        saveGoodTags(tags)
    }
    func removeGoodTag(_ tag: String) {
        var tags = loadGoodTags()
        tags.removeAll { $0 == tag }
        saveGoodTags(tags)
    }
    func updateGoodTag(old: String, new: String) {
        var tags = loadGoodTags()
        if let idx = tags.firstIndex(of: old) {
            tags[idx] = new
            saveGoodTags(tags)
        }
    }
    // MARK: - Bad Tags
    func loadBadTags() -> [String] {
        if let data = userDefaults?.data(forKey: badTagsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data), !decoded.isEmpty {
            return decoded
        }
        return defaultBadTags
    }
    func saveBadTags(_ tags: [String]) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        userDefaults?.set(data, forKey: badTagsKey)
    }
    func addBadTag(_ tag: String) {
        var tags = loadBadTags()
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        saveBadTags(tags)
    }
    func removeBadTag(_ tag: String) {
        var tags = loadBadTags()
        tags.removeAll { $0 == tag }
        saveBadTags(tags)
    }
    func updateBadTag(old: String, new: String) {
        var tags = loadBadTags()
        if let idx = tags.firstIndex(of: old) {
            tags[idx] = new
            saveBadTags(tags)
        }
    }
    // MARK: - Миграция старых тегов
    private func migrateOldTagsIfNeeded() {
        let oldTagsKey = "tags"
        if let data = userDefaults?.data(forKey: oldTagsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data), !decoded.isEmpty {
            // Мигрируем все старые теги в goodTags
            saveGoodTags(decoded)
            userDefaults?.removeObject(forKey: oldTagsKey)
        }
    }
} 