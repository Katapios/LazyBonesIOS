import XCTest
@testable import LazyBones

final class PostStoreAdapterTests: XCTestCase {
    
    var mockPostStore: MockPostStore!
    var adapter: PostStoreAdapter!
    
    override func setUp() {
        super.setUp()
        mockPostStore = MockPostStore()
        adapter = PostStoreAdapter(postStore: mockPostStore)
    }
    
    override func tearDown() {
        adapter = nil
        mockPostStore = nil
        super.tearDown()
    }
    
    // MARK: - Domain Posts Tests
    
    func testDomainPostsInitialization() {
        // Given
        let legacyPost = createSampleLegacyPost()
        mockPostStore.posts = [legacyPost]
        
        // When
        adapter = PostStoreAdapter(postStore: mockPostStore)
        
        // Then
        XCTAssertEqual(adapter.domainPosts.count, 1)
        XCTAssertEqual(adapter.domainPosts.first?.id, legacyPost.id)
    }
    
    func testAddPost() {
        // Given
        let domainPost = createSampleDomainPost()
        
        // When
        adapter.addPost(domainPost)
        
        // Then
        XCTAssertEqual(mockPostStore.addedPosts.count, 1)
        XCTAssertEqual(mockPostStore.addedPosts.first?.id, domainPost.id)
    }
    
    func testUpdatePost() {
        // Given
        let domainPost = createSampleDomainPost()
        
        // When
        adapter.updatePost(domainPost)
        
        // Then
        XCTAssertEqual(mockPostStore.updatedPosts.count, 1)
        XCTAssertEqual(mockPostStore.updatedPosts.first?.id, domainPost.id)
    }
    
    func testDeletePost() {
        // Given
        let domainPost = createSampleDomainPost()
        let legacyPost = PostAdapter.toLegacy(domainPost)
        mockPostStore.posts = [legacyPost]
        
        // When
        adapter.deletePost(domainPost)
        
        // Then
        XCTAssertEqual(mockPostStore.posts.count, 0)
        XCTAssertTrue(mockPostStore.saveCalled)
        XCTAssertTrue(mockPostStore.updateReportStatusCalled)
    }
    
    func testGetPostsForDate() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayPost = DomainPost(id: UUID(), date: today, goodItems: ["Today"], type: .regular)
        let yesterdayPost = DomainPost(id: UUID(), date: yesterday, goodItems: ["Yesterday"], type: .regular)
        
        mockPostStore.posts = [
            PostAdapter.toLegacy(todayPost),
            PostAdapter.toLegacy(yesterdayPost)
        ]
        adapter = PostStoreAdapter(postStore: mockPostStore)
        
        // When
        let todayPosts = adapter.getPosts(for: today)
        
        // Then
        XCTAssertEqual(todayPosts.count, 1)
        XCTAssertEqual(todayPosts.first?.goodItems.first, "Today")
    }
    
    func testGetTodayPost() {
        // Given
        let today = Date()
        let todayPost = DomainPost(id: UUID(), date: today, goodItems: ["Today"], type: .regular)
        
        mockPostStore.posts = [PostAdapter.toLegacy(todayPost)]
        adapter = PostStoreAdapter(postStore: mockPostStore)
        
        // When
        let result = adapter.getTodayPost()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.goodItems.first, "Today")
    }
    
    // MARK: - Legacy Protocol Tests
    
    func testGetPostsLegacy() {
        // Given
        let legacyPost = createSampleLegacyPost()
        mockPostStore.posts = [legacyPost]
        
        // When
        let posts = adapter.getPosts()
        
        // Then
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.id, legacyPost.id)
    }
    
    func testUpdatePostsLegacy() {
        // Given
        let legacyPosts = [createSampleLegacyPost()]
        
        // When
        adapter.updatePosts(legacyPosts)
        
        // Then
        XCTAssertEqual(mockPostStore.posts.count, 1)
        XCTAssertTrue(mockPostStore.saveCalled)
    }
    
    // MARK: - Status Management Tests
    
    func testUpdateReportStatus() {
        // When
        adapter.updateReportStatus()
        
        // Then
        XCTAssertTrue(mockPostStore.updateReportStatusCalled)
    }
    
    // MARK: - Data Management Tests
    
    func testSave() {
        // When
        adapter.save()
        
        // Then
        XCTAssertTrue(mockPostStore.saveCalled)
    }
    
    func testLoad() {
        // When
        adapter.load()
        
        // Then
        XCTAssertTrue(mockPostStore.loadCalled)
    }
    
    func testClearAllPosts() {
        // When
        adapter.clearAllPosts()
        
        // Then
        XCTAssertTrue(mockPostStore.clearCalled)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleLegacyPost() -> Post {
        return Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Хорошее дело 1"],
            badItems: ["Плохое дело 1"],
            published: true,
            voiceNotes: [VoiceNote(id: UUID(), path: "/path/to/voice.m4a")],
            type: .regular,
            isEvaluated: false,
            evaluationResults: nil,
            authorUsername: nil,
            authorFirstName: nil,
            authorLastName: nil,
            isExternal: false,
            externalVoiceNoteURLs: nil,
            externalText: nil,
            externalMessageId: nil,
            authorId: nil
        )
    }
    
    private func createSampleDomainPost() -> DomainPost {
        return DomainPost(
            id: UUID(),
            date: Date(),
            goodItems: ["Хорошее дело 1"],
            badItems: ["Плохое дело 1"],
            published: true,
            voiceNotes: [DomainVoiceNote(id: UUID(), url: URL(fileURLWithPath: "/path/to/voice.m4a"), duration: 30.0)],
            type: .regular,
            isEvaluated: false,
            evaluationResults: nil
        )
    }
}

// MARK: - Mock PostStore

class MockPostStore: ObservableObject {
    
    @Published var posts: [Post] = []
    @Published var reportStatus: ReportStatus = .notStarted
    
    var addedPosts: [Post] = []
    var updatedPosts: [Post] = []
    var saveCalled = false
    var loadCalled = false
    var clearCalled = false
    var updateReportStatusCalled = false
    
    func add(post: Post) {
        addedPosts.append(post)
        posts.append(post)
    }
    
    func update(post: Post) {
        updatedPosts.append(post)
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
    
    func save() {
        saveCalled = true
    }
    
    func load() {
        loadCalled = true
    }
    
    func clear() {
        clearCalled = true
        posts.removeAll()
    }
    
    func updateReportStatus() {
        updateReportStatusCalled = true
    }
}
