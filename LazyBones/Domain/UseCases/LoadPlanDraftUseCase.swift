import Foundation

// MARK: - LoadPlanDraft
struct LoadPlanDraftInput {
    let date: Date
}

enum LoadPlanDraftError: Error, LocalizedError {
    case repositoryUnavailable
    
    var errorDescription: String? {
        switch self {
        case .repositoryUnavailable:
            return "Недоступен репозиторий плана"
        }
    }
}

protocol LoadPlanDraftUseCaseProtocol: UseCaseProtocol where
    Input == LoadPlanDraftInput,
    Output == [String],
    ErrorType == LoadPlanDraftError {}

final class LoadPlanDraftUseCase: LoadPlanDraftUseCaseProtocol {
    private let planningRepository: PlanningRepositoryProtocol
    
    init(planningRepository: PlanningRepositoryProtocol) {
        self.planningRepository = planningRepository
    }
    
    func execute(input: LoadPlanDraftInput) async throws -> [String] {
        return planningRepository.loadPlan(for: input.date)
    }
}
