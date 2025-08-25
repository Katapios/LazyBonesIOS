import Foundation

protocol RemoveTodayRegularReportUseCaseProtocol {
    func execute()
}

/// Заглушка UC: удаление сегодняшнего regular-отчёта из хранилища постов
final class RemoveTodayRegularReportUseCase: RemoveTodayRegularReportUseCaseProtocol {
    private let postsProvider: PostsProviderProtocol
    
    init(postsProvider: PostsProviderProtocol) {
        self.postsProvider = postsProvider
    }
    
    func execute() {
        let today = Calendar.current.startOfDay(for: Date())
        var posts = postsProvider.getPosts()
        posts.removeAll { post in
            post.type == .regular && Calendar.current.isDate(post.date, inSameDayAs: today)
        }
        postsProvider.updatePosts(posts)
    }
}
