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
        
        // Перезаписываем отчёт за текущий день по ТИПУ (regular/custom) только для внутренних постов
        // Сохраняем отчёты за другие дни и внешние/iCloud без изменений
        var updatedPosts = posts.filter { existing in
            // Удаляем точное совпадение по id
            if existing.id == post.id { return false }
            // Для перезаписи: тот же день и тот же тип, и оба поста внутренние
            let sameDay = DateUtils.isSameDay(existing.date, post.date)
            let sameType = (existing.type == post.type)
            let isInternalExisting = (existing.isExternal != true) && (existing.type != .external) && (existing.type != .iCloud)
            let isInternalNew = (post.isExternal != true) && (post.type != .external) && (post.type != .iCloud)
            if sameDay && sameType && isInternalExisting && isInternalNew {
                // Удаляем существующий, чтобы положить свежий
                return false
            }
            return true
        }
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