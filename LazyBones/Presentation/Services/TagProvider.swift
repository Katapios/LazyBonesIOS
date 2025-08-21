import Foundation
import Combine

@MainActor
protocol TagProviderProtocol: AnyObject {
    var goodTags: [String] { get }
    var badTags: [String] { get }
    func refresh() async
}

@MainActor
final class DefaultTagProvider: ObservableObject, TagProviderProtocol {
    private let repository: any TagRepositoryProtocol
    @Published private(set) var goodTagsStorage: [String] = []
    @Published private(set) var badTagsStorage: [String] = []
    
    var goodTags: [String] { goodTagsStorage }
    var badTags: [String] { badTagsStorage }
    
    init(repository: any TagRepositoryProtocol) {
        self.repository = repository
    }
    
    func refresh() async {
        do {
            async let good = repository.loadGoodTags()
            async let bad = repository.loadBadTags()
            let (g, b) = try await (good, bad)
            goodTagsStorage = g
            badTagsStorage = b
        } catch {
            // Логируем, но не пробрасываем в UI-слой напрямую
            Logger.error("TagProvider refresh failed: \(error)", log: Logger.general)
        }
    }
}
