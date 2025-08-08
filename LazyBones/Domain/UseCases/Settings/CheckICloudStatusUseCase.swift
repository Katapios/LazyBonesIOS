import Foundation

/// Use case для проверки статуса iCloud
public final class CheckICloudStatusUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Проверить статус iCloud
    /// - Returns: `true`, если iCloud доступен, иначе `false`
    public func execute() async -> Bool {
        await settingsRepository.checkICloudStatus()
    }
}
