import Foundation
import Combine

/// Протокол для предоставления доменных отчетов в Clean Architecture
protocol DomainPostsProviderProtocol: ObservableObject {
    
    // MARK: - Published Properties
    var domainPosts: [DomainPost] { get }
    var reportStatus: ReportStatus { get }
    
    // MARK: - CRUD Operations
    func addPost(_ domainPost: DomainPost)
    func updatePost(_ domainPost: DomainPost)
    func deletePost(_ domainPost: DomainPost)
    
    // MARK: - Query Operations
    func getPosts(for date: Date) -> [DomainPost]
    func getTodayPost() -> DomainPost?
    
    // MARK: - Status Management
    func updateReportStatus()
    
    // MARK: - Data Management
    func save()
    func load()
    func clearAllPosts()
}
