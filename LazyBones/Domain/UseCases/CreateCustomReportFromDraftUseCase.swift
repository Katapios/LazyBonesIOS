import Foundation

// MARK: - Create/Update custom report from plan draft
struct CreateCustomReportFromDraftInput {
    let date: Date
    let items: [String]
}

enum CreateCustomReportFromDraftError: Error, LocalizedError {
    case emptyDraft
    case repositoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyDraft:
            return "План пуст — нечего сохранять как отчет"
        case .repositoryError(let err):
            return "Ошибка репозитория: \(err.localizedDescription)"
        }
    }
}

protocol CreateCustomReportFromDraftUseCaseProtocol: UseCaseProtocol where
    Input == CreateCustomReportFromDraftInput,
    Output == DomainPost,
    ErrorType == CreateCustomReportFromDraftError {}

final class CreateCustomReportFromDraftUseCase: CreateCustomReportFromDraftUseCaseProtocol {
    private let postRepository: PostRepositoryProtocol
    
    init(postRepository: PostRepositoryProtocol) {
        self.postRepository = postRepository
    }
    
    func execute(input: CreateCustomReportFromDraftInput) async throws -> DomainPost {
        let trimmed = input.items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { throw CreateCustomReportFromDraftError.emptyDraft }
        
        do {
            let todayPosts = try await postRepository.fetch(for: input.date)
            if var existing = todayPosts.first(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: input.date) }) {
                existing.goodItems = trimmed
                existing.published = false // важно для автоотправки
                try await postRepository.update(existing)
                return existing
            } else {
                let post = DomainPost(
                    date: input.date,
                    goodItems: trimmed,
                    badItems: [],
                    published: false,
                    voiceNotes: [],
                    type: .custom,
                    isEvaluated: nil,
                    evaluationResults: nil
                )
                try await postRepository.save(post)
                return post
            }
        } catch {
            throw CreateCustomReportFromDraftError.repositoryError(error)
        }
    }
}
