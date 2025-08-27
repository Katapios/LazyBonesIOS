import Foundation
import Combine

/// Адаптер для PostStore, который позволяет использовать его в Clean Architecture
/// Конвертирует между legacy Post и DomainPost моделями
class PostStoreAdapter: ObservableObject {
    
    // MARK: - Dependencies
    private let postStore: PostStore
    
    // MARK: - Published Properties
    @Published var domainPosts: [DomainPost] = []
    @Published var reportStatus: ReportStatus = .notStarted
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(postStore: PostStore = PostStore.shared) {
        self.postStore = postStore
        
        // Подписываемся на изменения в PostStore
        setupBindings()
        
        // Инициализируем данные
        syncFromPostStore()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Синхронизируем посты
        postStore.$posts
            .map { posts in
                posts.map { PostAdapter.toDomain($0) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$domainPosts)
        
        // Для reportStatus используем периодическое обновление,
        // так как это вычисляемое свойство
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ in self.postStore.reportStatus }
            .removeDuplicates()
            .assign(to: &$reportStatus)
    }
    
    private func syncFromPostStore() {
        domainPosts = postStore.posts.map { PostAdapter.toDomain($0) }
        reportStatus = postStore.reportStatus
    }
    
    // MARK: - Public Methods
    
    /// Добавить отчет
    func addPost(_ domainPost: DomainPost) {
        let legacyPost = PostAdapter.toLegacy(domainPost)
        DispatchQueue.main.async {
            self.postStore.add(post: legacyPost)
        }
    }
    
    /// Обновить отчет
    func updatePost(_ domainPost: DomainPost) {
        let legacyPost = PostAdapter.toLegacy(domainPost)
        DispatchQueue.main.async {
            self.postStore.update(post: legacyPost)
        }
    }
    
    /// Удалить отчет
    func deletePost(_ domainPost: DomainPost) {
        // PostStore не имеет метода delete, поэтому удаляем из массива
        DispatchQueue.main.async {
            self.postStore.posts.removeAll { $0.id == domainPost.id }
            self.postStore.save()
            self.postStore.updateReportStatus()
        }
    }
    
    /// Получить отчеты за конкретную дату
    func getPosts(for date: Date) -> [DomainPost] {
        return domainPosts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Получить отчет за сегодня
    func getTodayPost() -> DomainPost? {
        return domainPosts.first { Calendar.current.isDateInToday($0.date) }
    }
    
    /// Обновить статус отчета
    func updateReportStatus() {
        DispatchQueue.main.async {
            self.postStore.updateReportStatus()
        }
    }
    
    /// Очистить все отчеты
    func clearAllPosts() {
        DispatchQueue.main.async {
            self.postStore.clear()
        }
    }
    
    /// Сохранить данные
    func save() {
        DispatchQueue.main.async {
            self.postStore.save()
        }
    }
    
    /// Загрузить данные
    func load() {
        DispatchQueue.main.async {
            self.postStore.load()
        }
    }
}

// MARK: - Protocol Conformance

// Legacy PostsProviderProtocol для обратной совместимости
extension PostStoreAdapter: PostsProviderProtocol {
    func getPosts() -> [Post] {
        return postStore.posts
    }
    
    func updatePosts(_ posts: [Post]) {
        DispatchQueue.main.async {
            self.postStore.posts = posts
            self.postStore.save()
        }
    }
}

// Clean Architecture DomainPostsProviderProtocol
extension PostStoreAdapter: DomainPostsProviderProtocol {
    // domainPosts и reportStatus уже объявлены как @Published свойства
}
