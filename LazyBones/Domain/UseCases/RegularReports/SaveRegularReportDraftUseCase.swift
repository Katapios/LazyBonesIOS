import Foundation

protocol SaveRegularReportDraftUseCaseProtocol {
    func execute(_ draft: RegularReportDraft)
}

/// Заглушка UC: сохранение черновика обычного отчёта за день
final class SaveRegularReportDraftUseCase: SaveRegularReportDraftUseCaseProtocol {
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(userDefaultsManager: UserDefaultsManagerProtocol) {
        self.userDefaultsManager = userDefaultsManager
    }
    
    func execute(_ draft: RegularReportDraft) {
        let key = RegularReportDraftStorageKey.forDay(draft.date)
        do {
            let data = try JSONEncoder().encode(draft)
            userDefaultsManager.set(data, forKey: key)
        } catch {
            // Логируем молча, чтобы не менять существующее поведение UI
            print("[SaveRegularReportDraftUseCase] Failed to encode draft: \(error)")
        }
    }
}
