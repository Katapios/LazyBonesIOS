import Foundation

/// Use case для обновления статуса отчета
public final class UpdateReportStatusUseCase {
    private let settingsRepository: SettingsRepositoryProtocol
    
    public init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    /// Обновить статус отчета
    /// - Parameter status: Новый статус отчета
    public func execute(_ status: ReportStatus) async throws {
        try await settingsRepository.updateReportStatus(status)
    }
}
