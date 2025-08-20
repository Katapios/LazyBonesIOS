import Foundation

final class ExternalPostRepository: ExternalPostRepositoryProtocol {
    private let userDefaults: UserDefaultsManagerProtocol
    private let storageKey = "externalPosts"
    private let calendar: Calendar
    
    init(userDefaultsManager: UserDefaultsManagerProtocol, calendar: Calendar = .current) {
        self.userDefaults = userDefaultsManager
        self.calendar = calendar
    }
    
    func fetchAll() async throws -> [DomainPost] {
        let posts: [Post] = load()
        return PostMapper.toDomainModels(posts)
    }
    
    func fetch(for date: Date) async throws -> [DomainPost] {
        let posts: [Post] = load()
        let filtered = posts.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return PostMapper.toDomainModels(filtered)
    }
    
    func saveAll(_ posts: [DomainPost]) async throws {
        let dataModels = PostMapper.toDataModels(posts)
        save(dataModels)
    }
    
    func clear() async throws {
        userDefaults.remove(forKey: storageKey)
    }
    
    // MARK: - Private
    private func load() -> [Post] {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func save(_ posts: [Post]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
