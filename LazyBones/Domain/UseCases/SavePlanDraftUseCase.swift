import Foundation

// MARK: - SavePlanDraft
struct SavePlanDraftInput {
    let date: Date
    let items: [String]
}

enum SavePlanDraftError: Error, LocalizedError {
    case repositoryUnavailable
    
    var errorDescription: String? {
        switch self {
        case .repositoryUnavailable:
            return "Недоступен репозиторий плана"
        }
    }
}

protocol SavePlanDraftUseCaseProtocol: UseCaseProtocol where
    Input == SavePlanDraftInput,
    Output == Void,
    ErrorType == SavePlanDraftError {}

final class SavePlanDraftUseCase: SavePlanDraftUseCaseProtocol {
    private let planningRepository: PlanningRepositoryProtocol
    
    init(planningRepository: PlanningRepositoryProtocol) {
        self.planningRepository = planningRepository
    }
    
    func execute(input: SavePlanDraftInput) async throws -> Void {
        planningRepository.savePlan(input.items, for: input.date)
    }
}
