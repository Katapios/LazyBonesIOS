import XCTest
@testable import LazyBones

@MainActor
class PostRepositoryTests: XCTestCase {
    
    var repository: PostRepository!
    var mockDataSource: PRT_MockPostDataSource!
    
    override func setUp() {
        super.setUp()
        mockDataSource = PRT_MockPostDataSource()
        repository = PostRepository(dataSource: mockDataSource)
    }
    
    override func tearDown() {
        repository = nil
        mockDataSource = nil
        super.tearDown()
    }
    
    func testSave() async throws {
        // Given
        let domainPost = DomainPost(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил"],
            badItems: ["Не спал"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        
        // When
        try await repository.save(domainPost)
        
        // Then
        XCTAssertEqual(mockDataSource.saveCallCount, 1)
        XCTAssertEqual(mockDataSource.loadCallCount, 1)
    }
    
    func testFetch() async throws {
        // Given
        let dataPosts = [
            Post(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular),
            Post(id: UUID(), date: Date(), goodItems: ["Гулял"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        mockDataSource.mockPosts = dataPosts
        
        // When
        let domainPosts = try await repository.fetch()
        
        // Then
        XCTAssertEqual(domainPosts.count, 2)
        XCTAssertEqual(domainPosts[0].goodItems, ["Кодил"])
        XCTAssertEqual(domainPosts[1].goodItems, ["Гулял"])
    }
    
    func testFetchForDate() async throws {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let dataPosts = [
            Post(id: UUID(), date: today, goodItems: ["Сегодня"], badItems: [], published: false, voiceNotes: [], type: .regular),
            Post(id: UUID(), date: yesterday, goodItems: ["Вчера"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        mockDataSource.mockPosts = dataPosts
        
        // When
        let domainPosts = try await repository.fetch(for: today)
        
        // Then
        XCTAssertEqual(domainPosts.count, 1)
        XCTAssertEqual(domainPosts[0].goodItems, ["Сегодня"])
    }
    
    func testDelete() async throws {
        // Given
        let postId = UUID()
        let dataPosts = [
            Post(id: postId, date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular)
        ]
        mockDataSource.mockPosts = dataPosts
        
        let domainPost = DomainPost(id: postId, date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular)
        
        // When
        try await repository.delete(domainPost)
        
        // Then
        XCTAssertEqual(mockDataSource.saveCallCount, 1)
        XCTAssertEqual(mockDataSource.loadCallCount, 1)
    }
}

// MARK: - Mock Data Source
class PRT_MockPostDataSource: PostDataSourceProtocol {
    var mockPosts: [Post] = []
    var saveCallCount = 0
    var loadCallCount = 0
    var clearCallCount = 0
    
    func save(_ posts: [Post]) async throws {
        saveCallCount += 1
        mockPosts = posts
    }
    
    func load() async throws -> [Post] {
        loadCallCount += 1
        return mockPosts
    }
    
    func clear() async throws {
        clearCallCount += 1
        mockPosts = []
    }
} 