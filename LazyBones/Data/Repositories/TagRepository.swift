import Foundation

/// Реализация репозитория тегов
class TagRepository: TagRepositoryProtocol {
    
    private let userDefaults: UserDefaults
    private let goodTagsKey = "goodTags"
    private let badTagsKey = "badTags"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func saveGoodTags(_ tags: [String]) async throws {
        userDefaults.set(tags, forKey: goodTagsKey)
        userDefaults.synchronize()
    }
    
    func saveBadTags(_ tags: [String]) async throws {
        userDefaults.set(tags, forKey: badTagsKey)
        userDefaults.synchronize()
    }
    
    func loadGoodTags() async throws -> [String] {
        return userDefaults.stringArray(forKey: goodTagsKey) ?? []
    }
    
    func loadBadTags() async throws -> [String] {
        return userDefaults.stringArray(forKey: badTagsKey) ?? []
    }
    
    func addGoodTag(_ tag: String) async throws {
        var tags = try await loadGoodTags()
        if !tags.contains(tag) {
            tags.append(tag)
            try await saveGoodTags(tags)
        }
    }
    
    func addBadTag(_ tag: String) async throws {
        var tags = try await loadBadTags()
        if !tags.contains(tag) {
            tags.append(tag)
            try await saveBadTags(tags)
        }
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
        if let index = tags.firstIndex(of: old) {
            tags[index] = new
            try await saveGoodTags(tags)
        }
    }
    
    func updateBadTag(old: String, new: String) async throws {
        var tags = try await loadBadTags()
        if let index = tags.firstIndex(of: old) {
            tags[index] = new
            try await saveBadTags(tags)
        }
    }
} 