import Foundation

// Input for getting external reports
struct GetExternalReportsInput {
    let date: Date?
    init(date: Date? = nil) { self.date = date }
}

// UseCase protocol
protocol GetExternalReportsUseCaseProtocol: UseCaseProtocol where
    Input == GetExternalReportsInput,
    Output == [DomainPost],
    ErrorType == GetReportsError {}

// Implementation
final class GetExternalReportsUseCase: GetExternalReportsUseCaseProtocol {
    private let repository: ExternalPostRepositoryProtocol
    
    init(repository: ExternalPostRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: GetExternalReportsInput) async throws -> [DomainPost] {
        do {
            if let date = input.date {
                return try await repository.fetch(for: date)
            } else {
                return try await repository.fetchAll()
            }
        } catch {
            throw GetReportsError.repositoryError(error)
        }
    }
}
