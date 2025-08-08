import Foundation

/// Use case для экспорта данных в iCloud
public final class ExportToICloudUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Экспортировать данные в iCloud
    /// - Returns: URL экспортированного файла
    public func execute() async throws -> URL {
        try await settingsRepository.exportToICloud()
    }
}
