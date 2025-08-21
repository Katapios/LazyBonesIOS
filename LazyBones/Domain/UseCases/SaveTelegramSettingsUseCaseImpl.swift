import Foundation

public final class SaveTelegramSettingsUseCaseImpl: SaveTelegramSettingsUseCase {
    private let repository: TelegramSettingsRepository
    
    public init(repository: TelegramSettingsRepository) {
        self.repository = repository
    }
    
    public func execute(_ settings: TelegramSettings) {
        repository.save(settings)
    }
}
