import Foundation

protocol RefreshExternalReportsUseCaseProtocol {
    func execute() async throws
}

final class RefreshExternalReportsUseCase: RefreshExternalReportsUseCaseProtocol {
    private let repository: ExternalPostRepositoryProtocol
    private let fetcher: TelegramFetcherProtocol
    
    init(repository: ExternalPostRepositoryProtocol, fetcher: TelegramFetcherProtocol) {
        self.repository = repository
        self.fetcher = fetcher
    }
    
    func execute() async throws {
        let fetched = try await fetcher.fetchNewExternalPosts()
        try await repository.saveAll(fetched)
    }
}
