import Foundation

/// Use case для получения статуса отчета
public final class GetReportStatusUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Получить текущий статус отчета
    /// - Returns: Текущий статус отчета
    public func execute() async throws -> ReportStatus {
        try await settingsRepository.getReportStatus()
    }
}
