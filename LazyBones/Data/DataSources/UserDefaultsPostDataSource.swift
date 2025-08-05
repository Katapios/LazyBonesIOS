import Foundation

/// Реализация источника данных отчетов на основе UserDefaults
class UserDefaultsPostDataSource: PostDataSourceProtocol {
    
    private let userDefaults: UserDefaults
    private let postsKey = "posts"
    
    init(userDefaults: UserDefaults? = AppConfig.sharedUserDefaults) {
        self.userDefaults = userDefaults ?? .standard
    }
    
    func save(_ posts: [Post]) async throws {
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults.set(data, forKey: postsKey)
            userDefaults.synchronize()
        } catch {
            throw PostDataSourceError.encodingError(error)
        }
    }
    
    func load() async throws -> [Post] {
        guard let data = userDefaults.data(forKey: postsKey) else {
            return []
        }
        
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            return posts
        } catch {
            throw PostDataSourceError.decodingError(error)
        }
    }
    
    func clear() async throws {
        userDefaults.removeObject(forKey: postsKey)
        userDefaults.synchronize()
    }
}

/// Ошибки источника данных
enum PostDataSourceError: Error, LocalizedError {
    case encodingError(Error)
    case decodingError(Error)
    case storageError(Error)
    
    var errorDescription: String? {
        switch self {
        case .encodingError(let error):
            return "Ошибка кодирования данных: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Ошибка декодирования данных: \(error.localizedDescription)"
        case .storageError(let error):
            return "Ошибка хранилища: \(error.localizedDescription)"
        }
    }
} 