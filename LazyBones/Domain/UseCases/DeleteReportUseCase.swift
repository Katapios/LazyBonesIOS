import Foundation

/// Входные данные для удаления отчета
struct DeleteReportInput {
    let report: DomainPost
    
    init(report: DomainPost) {
        self.report = report
    }
}

/// Ошибки удаления отчета
enum DeleteReportError: Error, LocalizedError {
    case repositoryError(Error)
    case reportNotFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Ошибка удаления: \(error.localizedDescription)"
        case .reportNotFound:
            return "Отчет не найден"
        case .unauthorized:
            return "Нет прав для удаления"
        }
    }
}

/// Use Case для удаления отчетов
protocol DeleteReportUseCaseProtocol: UseCaseProtocol where
    Input == DeleteReportInput,
    Output == Void,
    ErrorType == DeleteReportError
{
}

/// Реализация Use Case для удаления отчетов
class DeleteReportUseCase: DeleteReportUseCaseProtocol {
    
    private let postRepository: PostRepositoryProtocol
    
    init(postRepository: PostRepositoryProtocol) {
        self.postRepository = postRepository
    }
    
    func execute(input: DeleteReportInput) async throws -> Void {
        do {
            try await postRepository.delete(input.report)
        } catch {
            throw DeleteReportError.repositoryError(error)
        }
    }
} 