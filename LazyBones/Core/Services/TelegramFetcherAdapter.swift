import Foundation

/// Адаптер инфраструктуры: оборачивает TelegramIntegrationService в TelegramFetcherProtocol
final class TelegramFetcherAdapter: TelegramFetcherProtocol {
    private let integrationService: TelegramIntegrationServiceType
    
    init(integrationService: TelegramIntegrationServiceType) {
        self.integrationService = integrationService
    }
    
    func fetchNewExternalPosts() async throws -> [DomainPost] {
        // TelegramIntegrationService сейчас использует completion-based API.
        // Оборачиваем в continuation, затем возвращаем доменные модели из актуального состояния externalPosts.
        return try await withCheckedThrowingContinuation { continuation in
            integrationService.fetchExternalPosts { success in
                if success {
                    let domain = PostMapper.toDomainModels(self.integrationService.getAllPosts())
                    continuation.resume(returning: domain)
                } else {
                    let err = NSError(domain: "TelegramFetcherAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch external posts from Telegram"])
                    continuation.resume(throwing: GetReportsError.repositoryError(err))
                }
            }
        }
    }
}
