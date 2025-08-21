import Foundation

public final class LoadTelegramSettingsUseCaseImpl: LoadTelegramSettingsUseCase {
    private let repository: TelegramSettingsRepository
    
    public init(repository: TelegramSettingsRepository) {
        self.repository = repository
    }
    
    public func execute() -> TelegramSettings {
        repository.load()
    }
}
