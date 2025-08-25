import Foundation

protocol LoadRegularReportDraftUseCaseProtocol {
    func execute(date: Date) -> RegularReportDraft?
}

/// Заглушка UC: загрузка черновика обычного отчёта за день
final class LoadRegularReportDraftUseCase: LoadRegularReportDraftUseCaseProtocol {
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(userDefaultsManager: UserDefaultsManagerProtocol) {
        self.userDefaultsManager = userDefaultsManager
    }
    
    func execute(date: Date) -> RegularReportDraft? {
        let key = RegularReportDraftStorageKey.forDay(date)
        guard let data = userDefaultsManager.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(RegularReportDraft.self, from: data)
        } catch {
            print("[LoadRegularReportDraftUseCase] Failed to decode draft: \(error)")
            return nil
        }
    }
}
