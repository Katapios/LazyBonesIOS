import Foundation

public final class SaveAutoSendSettingsUseCaseImpl: SaveAutoSendSettingsUseCase {
    private let repository: AutoSendSettingsRepository
    
    public init(repository: AutoSendSettingsRepository) {
        self.repository = repository
    }
    
    public func execute(_ settings: AutoSendSettings) {
        repository.save(settings)
    }
}
