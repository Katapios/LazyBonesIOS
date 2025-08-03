import Foundation

/// Входные данные для получения отчетов
struct GetReportsInput {
    let date: Date?
    let type: PostType?
    let includeExternal: Bool
    
    init(
        date: Date? = nil,
        type: PostType? = nil,
        includeExternal: Bool = true
    ) {
        self.date = date
        self.type = type
        self.includeExternal = includeExternal
    }
}

/// Ошибки получения отчетов
enum GetReportsError: Error, LocalizedError {
    case repositoryError(Error)
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Ошибка загрузки: \(error.localizedDescription)"
        case .invalidDate:
            return "Некорректная дата"
        }
    }
}

/// Use Case для получения отчетов
protocol GetReportsUseCaseProtocol: UseCaseProtocol where
    Input == GetReportsInput,
    Output == [DomainPost],
    ErrorType == GetReportsError {
}

/// Реализация Use Case для получения отчетов
class GetReportsUseCase: GetReportsUseCaseProtocol {
    
    private let postRepository: PostRepositoryProtocol
    
    init(postRepository: PostRepositoryProtocol) {
        self.postRepository = postRepository
    }
    
    func execute(input: GetReportsInput) async throws -> [DomainPost] {
        do {
            var posts: [DomainPost]
            
            if let date = input.date {
                posts = try await postRepository.fetch(for: date)
            } else {
                posts = try await postRepository.fetch()
            }
            
            // Фильтрация по типу
            if let type = input.type {
                posts = posts.filter { $0.type == type }
            }
            
            // Фильтрация внешних отчетов
            if !input.includeExternal {
                posts = posts.filter { $0.isExternal != true }
            }
            
            return posts
        } catch {
            throw GetReportsError.repositoryError(error)
        }
    }
} 