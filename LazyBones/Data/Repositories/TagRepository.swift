import Foundation

/// Реализация репозитория тегов на общем UserDefaults c JSON-хранением и дефолтами
class TagRepository: TagRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let goodTagsKey = "goodTags"
    private let badTagsKey = "badTags"
    private let defaultGoodTags = ["Здоровье", "Работа", "Учёба", "Спорт", "Сон", "Питание", "Отдых", "Чтение", "Творчество", "Общение"]
    private let defaultBadTags = ["Прокрастинация", "Переедание", "Мало сна", "Стресс", "Лень", "Зависимость", "Скандал", "Трата времени"]

    init(userDefaults: UserDefaults = AppConfig.sharedUserDefaults) {
        self.userDefaults = userDefaults
    }

    // MARK: - Persistence (JSON)
    private func readJSONArray(forKey key: String) -> [String]? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return (try? JSONDecoder().decode([String].self, from: data))
    }

    private func writeJSONArray(_ array: [String], forKey key: String) {
        guard let data = try? JSONEncoder().encode(array) else { return }
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()
    }

    private func migrateIfNeeded(forKey key: String) {
        // Если JSON отсутствует, но есть старый формат stringArray — мигрируем его в JSON
        if userDefaults.data(forKey: key) == nil, let legacy = userDefaults.stringArray(forKey: key) {
            writeJSONArray(legacy, forKey: key)
            // Нельзя удалять ключ, так как и старый, и новый форматы используют один и тот же ключ.
            // Запись JSON поверх старого значения достаточно, UserDefaults хранит только последнее значение.
        }
    }

    // MARK: - API
    func saveGoodTags(_ tags: [String]) async throws {
        writeJSONArray(tags, forKey: goodTagsKey)
    }

    func saveBadTags(_ tags: [String]) async throws {
        writeJSONArray(tags, forKey: badTagsKey)
    }

    func loadGoodTags() async throws -> [String] {
        migrateIfNeeded(forKey: goodTagsKey)
        if userDefaults.data(forKey: goodTagsKey) != nil {
            // JSON уже инициализирован — читаем и санитизируем
            let loaded = readJSONArray(forKey: goodTagsKey) ?? []
            // Удаляем пустые/пробельные и делаем уникальным порядок-сохраняющим способом
            var seen = Set<String>()
            let cleaned = loaded.compactMap { raw -> String? in
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !seen.contains(t) else { return nil }
                seen.insert(t)
                return t
            }
            if cleaned != loaded { writeJSONArray(cleaned, forKey: goodTagsKey) }
            return cleaned
        } else {
            // Первый запуск: инициализируем дефолтами и сохраняем
            writeJSONArray(defaultGoodTags, forKey: goodTagsKey)
            return defaultGoodTags
        }
    }

    func loadBadTags() async throws -> [String] {
        migrateIfNeeded(forKey: badTagsKey)
        if userDefaults.data(forKey: badTagsKey) != nil {
            let loaded = readJSONArray(forKey: badTagsKey) ?? []
            var seen = Set<String>()
            let cleaned = loaded.compactMap { raw -> String? in
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !seen.contains(t) else { return nil }
                seen.insert(t)
                return t
            }
            if cleaned != loaded { writeJSONArray(cleaned, forKey: badTagsKey) }
            return cleaned
        } else {
            writeJSONArray(defaultBadTags, forKey: badTagsKey)
            return defaultBadTags
        }
    }

    func addGoodTag(_ tag: String) async throws {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var tags = try await loadGoodTags()
        if !tags.contains(t) { tags.append(t); try await saveGoodTags(tags) }
    }

    func addBadTag(_ tag: String) async throws {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var tags = try await loadBadTags()
        if !tags.contains(t) { tags.append(t); try await saveBadTags(tags) }
    }

    func removeGoodTag(_ tag: String) async throws {
        var tags = try await loadGoodTags()
        tags.removeAll { $0 == tag }
        try await saveGoodTags(tags)
    }

    func removeBadTag(_ tag: String) async throws {
        var tags = try await loadBadTags()
        tags.removeAll { $0 == tag }
        try await saveBadTags(tags)
    }

    func updateGoodTag(old: String, new: String) async throws {
        var tags = try await loadGoodTags()
        if let index = tags.firstIndex(of: old) { tags[index] = new; try await saveGoodTags(tags) }
    }

    func updateBadTag(old: String, new: String) async throws {
        var tags = try await loadBadTags()
        if let index = tags.firstIndex(of: old) { tags[index] = new; try await saveBadTags(tags) }
    }
}
 