import Foundation

public final class LoadAutoSendSettingsUseCaseImpl: LoadAutoSendSettingsUseCase {
    private let repository: AutoSendSettingsRepository
    
    public init(repository: AutoSendSettingsRepository) {
        self.repository = repository
    }
    
    public func execute() -> AutoSendSettings {
        return repository.load()
    }
}
