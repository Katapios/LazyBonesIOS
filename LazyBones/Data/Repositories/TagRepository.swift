import Foundation

/// Реализация репозитория тегов, делегирующая в LocalReportService
class TagRepository: TagRepositoryProtocol {
    
    private let localService: LocalReportService
    
    init(localService: LocalReportService = .shared) {
        self.localService = localService
    }
    
    func saveGoodTags(_ tags: [String]) async throws {
        localService.saveGoodTags(tags)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func saveBadTags(_ tags: [String]) async throws {
        localService.saveBadTags(tags)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func loadGoodTags() async throws -> [String] {
        localService.loadGoodTags()
    }
    
    func loadBadTags() async throws -> [String] {
        localService.loadBadTags()
    }
    
    func addGoodTag(_ tag: String) async throws {
        localService.addGoodTag(tag)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func addBadTag(_ tag: String) async throws {
        localService.addBadTag(tag)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func removeGoodTag(_ tag: String) async throws {
        localService.removeGoodTag(tag)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func removeBadTag(_ tag: String) async throws {
        localService.removeBadTag(tag)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func updateGoodTag(old: String, new: String) async throws {
        localService.updateGoodTag(old: old, new: new)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
    
    func updateBadTag(old: String, new: String) async throws {
        localService.updateBadTag(old: old, new: new)
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
    }
}
 