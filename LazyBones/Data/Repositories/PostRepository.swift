import Foundation

/// Реализация репозитория отчетов
class PostRepository: PostRepositoryProtocol {
    
    private let dataSource: PostDataSourceProtocol
    
    init(dataSource: PostDataSourceProtocol) {
        self.dataSource = dataSource
    }
    
    func save(_ post: DomainPost) async throws {
        let posts = try await dataSource.load()
        let dataPost = PostMapper.toDataModel(post)
        
        // Обновляем существующий пост или добавляем новый
        var updatedPosts = posts.filter { $0.id != post.id }
        updatedPosts.append(dataPost)
        
        try await dataSource.save(updatedPosts)
    }
    
    func fetch() async throws -> [DomainPost] {
        let posts = try await dataSource.load()
        return PostMapper.toDomainModels(posts)
    }
    
    func fetch(for date: Date) async throws -> [DomainPost] {
        let allPosts = try await fetch()
        return allPosts.filter { DateUtils.isSameDay($0.date, date) }
    }
    
    func update(_ post: DomainPost) async throws {
        try await save(post)
    }
    
    func delete(_ post: DomainPost) async throws {
        let posts = try await dataSource.load()
        let filteredPosts = posts.filter { $0.id != post.id }
        try await dataSource.save(filteredPosts)
    }
    
    func clear() async throws {
        try await dataSource.clear()
    }
} 