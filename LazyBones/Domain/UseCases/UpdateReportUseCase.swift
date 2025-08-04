import Foundation

/// Входные данные для обновления отчета
struct UpdateReportInput {
    let report: DomainPost
    
    init(report: DomainPost) {
        self.report = report
    }
}

/// Ошибки обновления отчета
enum UpdateReportError: Error, LocalizedError {
    case repositoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Ошибка обновления отчета: \(error.localizedDescription)"
        }
    }
}

/// Use Case для обновления отчета
protocol UpdateReportUseCaseProtocol: UseCaseProtocol where
    Input == UpdateReportInput,
    Output == DomainPost,
    ErrorType == UpdateReportError {
}

/// Реализация Use Case для обновления отчета
class UpdateReportUseCase: UpdateReportUseCaseProtocol {
    
    private let postRepository: PostRepositoryProtocol
    
    init(postRepository: PostRepositoryProtocol) {
        self.postRepository = postRepository
    }
    
    func execute(input: UpdateReportInput) async throws -> DomainPost {
        do {
            try await postRepository.update(input.report)
            return input.report
        } catch {
            throw UpdateReportError.repositoryError(error)
        }
    }
} 