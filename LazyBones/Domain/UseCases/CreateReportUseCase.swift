import Foundation

/// Входные данные для создания отчета
struct CreateReportInput {
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [DomainVoiceNote]
    let type: PostType
    let isEvaluated: Bool?
    let evaluationResults: [Bool]?
    
    init(
        goodItems: [String] = [],
        badItems: [String] = [],
        voiceNotes: [DomainVoiceNote] = [],
        type: PostType = .regular,
        isEvaluated: Bool? = nil,
        evaluationResults: [Bool]? = nil
    ) {
        self.goodItems = goodItems
        self.badItems = badItems
        self.voiceNotes = voiceNotes
        self.type = type
        self.isEvaluated = isEvaluated
        self.evaluationResults = evaluationResults
    }
}

/// Ошибки создания отчета
enum CreateReportError: Error, LocalizedError {
    case emptyReport
    case invalidDate
    case repositoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyReport:
            return "Отчет не может быть пустым"
        case .invalidDate:
            return "Некорректная дата"
        case .repositoryError(let error):
            return "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

/// Use Case для создания отчета
protocol CreateReportUseCaseProtocol: UseCaseProtocol where
    Input == CreateReportInput,
    Output == DomainPost,
    ErrorType == CreateReportError {
}

/// Реализация Use Case для создания отчета
class CreateReportUseCase: CreateReportUseCaseProtocol {
    
    private let postRepository: PostRepositoryProtocol
    
    init(postRepository: PostRepositoryProtocol) {
        self.postRepository = postRepository
    }
    
    func execute(input: CreateReportInput) async throws -> DomainPost {
        // Валидация входных данных
        try validateInput(input)
        
        // Создание отчета
        let post = DomainPost(
            date: Date(),
            goodItems: input.goodItems,
            badItems: input.badItems,
            published: false,
            voiceNotes: input.voiceNotes,
            type: input.type,
            isEvaluated: input.isEvaluated,
            evaluationResults: input.evaluationResults
        )
        
        // Сохранение в репозиторий
        do {
            try await postRepository.save(post)
            return post
        } catch {
            throw CreateReportError.repositoryError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func validateInput(_ input: CreateReportInput) throws {
        // Проверяем, что отчет не пустой
        let hasGoodItems = !input.goodItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty
        let hasBadItems = !input.badItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty
        let hasVoiceNotes = !input.voiceNotes.isEmpty
        
        if !hasGoodItems && !hasBadItems && !hasVoiceNotes {
            throw CreateReportError.emptyReport
        }
    }
} 