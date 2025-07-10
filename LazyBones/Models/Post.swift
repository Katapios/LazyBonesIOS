import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
}

protocol PostStoreProtocol: ObservableObject {
    var posts: [Post] { get set }
    func load()
    func save()
    func add(post: Post)
    func clear()
}

class PostStore: ObservableObject, PostStoreProtocol {
    static let appGroup = "group.com.katapios.LazyBones"
    @Published var posts: [Post] = []
    
    private let userDefaults: UserDefaults?
    private let key = "posts"
    
    init() {
        userDefaults = UserDefaults(suiteName: Self.appGroup)
        load()
    }
    
    func load() {
        guard let data = userDefaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            posts = []
            return
        }
        posts = decoded.sorted { $0.date > $1.date }
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        userDefaults?.set(data, forKey: key)
    }
    
    func add(post: Post) {
        posts.append(post)
        save()
    }
    
    func clear() {
        posts = []
        save()
    }
} 