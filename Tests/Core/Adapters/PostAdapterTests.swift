import XCTest
@testable import LazyBones

final class PostAdapterTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createSamplePost() -> Post {
        return Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Хорошее дело 1", "Хорошее дело 2"],
            badItems: ["Плохое дело 1"],
            published: true,
            voiceNotes: [
                VoiceNote(id: UUID(), path: "/path/to/voice1.m4a", duration: 30.0),
                VoiceNote(id: UUID(), path: "/path/to/voice2.m4a", duration: 45.0)
            ],
            type: .regular,
            authorUsername: "testuser",
            authorFirstName: "Test",
            authorLastName: "User",
            isExternal: false,
            externalVoiceNoteURLs: nil,
            externalText: nil,
            externalMessageId: nil,
            authorId: 12345,
            isEvaluated: true,
            evaluationResults: [true, false, true]
        )
    }
    
    private func createSampleDomainPost() -> DomainPost {
        // Создаем тестовые голосовые заметки
        let domainVoiceNote1 = DomainVoiceNote(
            id: UUID(),
            url: URL(fileURLWithPath: "/path/to/voice1.m4a"),
            duration: 30.0
        )
        let domainVoiceNote2 = DomainVoiceNote(
            id: UUID(),
            url: URL(fileURLWithPath: "/path/to/voice2.m4a"),
            duration: 45.0
        )
        
        return DomainPost(
            id: UUID(),
            date: Date(),
            goodItems: ["Хорошее дело 1", "Хорошее дело 2"],
            badItems: ["Плохое дело 1"],
            published: true,
            voiceNotes: [domainVoiceNote1, domainVoiceNote2],
            type: .regular,
            authorUsername: "testuser",
            authorFirstName: "Test",
            authorLastName: "User",
            isExternal: false,
            externalVoiceNoteURLs: nil,
            externalText: nil,
            externalMessageId: nil,
            authorId: 12345,
            isEvaluated: true,
            evaluationResults: [true, false, true]
        )
    }
    
    // MARK: - Post -> DomainPost Tests
    
    func testPostToDomainConversion() {
        // Given
        let post = createSamplePost()
        
        // When
        let domainPost = PostAdapter.toDomain(post)
        
        // Then
        XCTAssertEqual(domainPost.id, post.id)
        XCTAssertEqual(domainPost.date, post.date)
        XCTAssertEqual(domainPost.goodItems, post.goodItems)
        XCTAssertEqual(domainPost.badItems, post.badItems)
        XCTAssertEqual(domainPost.published, post.published)
        XCTAssertEqual(domainPost.type, post.type)
        XCTAssertEqual(domainPost.authorUsername, post.authorUsername)
        XCTAssertEqual(domainPost.authorFirstName, post.authorFirstName)
        XCTAssertEqual(domainPost.authorLastName, post.authorLastName)
        XCTAssertEqual(domainPost.isExternal, post.isExternal)
        XCTAssertEqual(domainPost.authorId, post.authorId)
        XCTAssertEqual(domainPost.isEvaluated, post.isEvaluated)
        XCTAssertEqual(domainPost.evaluationResults, post.evaluationResults)
        
        // Voice notes
        XCTAssertEqual(domainPost.voiceNotes.count, post.voiceNotes.count)
        for (index, voiceNote) in domainPost.voiceNotes.enumerated() {
            XCTAssertEqual(voiceNote.id, post.voiceNotes[index].id)
            XCTAssertEqual(voiceNote.url.path, post.voiceNotes[index].path)
            XCTAssertEqual(voiceNote.duration, post.voiceNotes[index].duration)
        }
    }
    
    func testPostArrayToDomainConversion() {
        // Given
        let posts = [createSamplePost(), createSamplePost()]
        
        // When
        let domainPosts = PostAdapter.toDomain(posts)
        
        // Then
        XCTAssertEqual(domainPosts.count, posts.count)
        for (index, domainPost) in domainPosts.enumerated() {
            XCTAssertEqual(domainPost.id, posts[index].id)
            XCTAssertEqual(domainPost.goodItems, posts[index].goodItems)
        }
    }
    
    // MARK: - DomainPost -> Post Tests
    
    func testDomainPostToLegacyConversion() {
        // Given
        let domainPost = createSampleDomainPost()
        
        // When
        let post = PostAdapter.toLegacy(domainPost)
        
        // Then
        XCTAssertEqual(post.id, domainPost.id)
        XCTAssertEqual(post.date, domainPost.date)
        XCTAssertEqual(post.goodItems, domainPost.goodItems)
        XCTAssertEqual(post.badItems, domainPost.badItems)
        XCTAssertEqual(post.published, domainPost.published)
        XCTAssertEqual(post.type, domainPost.type)
        XCTAssertEqual(post.authorUsername, domainPost.authorUsername)
        XCTAssertEqual(post.authorFirstName, domainPost.authorFirstName)
        XCTAssertEqual(post.authorLastName, domainPost.authorLastName)
        XCTAssertEqual(post.isExternal, domainPost.isExternal)
        XCTAssertEqual(post.authorId, domainPost.authorId)
        XCTAssertEqual(post.isEvaluated, domainPost.isEvaluated)
        XCTAssertEqual(post.evaluationResults, domainPost.evaluationResults)
        
        // Voice notes
        XCTAssertEqual(post.voiceNotes.count, domainPost.voiceNotes.count)
        for (index, voiceNote) in post.voiceNotes.enumerated() {
            XCTAssertEqual(voiceNote.id, domainPost.voiceNotes[index].id)
            XCTAssertEqual(voiceNote.path, domainPost.voiceNotes[index].url.path)
            XCTAssertEqual(voiceNote.duration, domainPost.voiceNotes[index].duration)
        }
    }
    
    func testDomainPostArrayToLegacyConversion() {
        // Given
        let domainPosts = [createSampleDomainPost(), createSampleDomainPost()]
        
        // When
        let posts = PostAdapter.toLegacy(domainPosts)
        
        // Then
        XCTAssertEqual(posts.count, domainPosts.count)
        for (index, post) in posts.enumerated() {
            XCTAssertEqual(post.id, domainPosts[index].id)
            XCTAssertEqual(post.goodItems, domainPosts[index].goodItems)
        }
    }
    
    // MARK: - Round-trip Tests
    
    func testPostTodomainToLegacyRoundTrip() {
        // Given
        let originalPost = createSamplePost()
        
        // When
        let domainPost = PostAdapter.toDomain(originalPost)
        let convertedBackPost = PostAdapter.toLegacy(domainPost)
        
        // Then
        XCTAssertEqual(convertedBackPost.id, originalPost.id)
        XCTAssertEqual(convertedBackPost.date, originalPost.date)
        XCTAssertEqual(convertedBackPost.goodItems, originalPost.goodItems)
        XCTAssertEqual(convertedBackPost.badItems, originalPost.badItems)
        XCTAssertEqual(convertedBackPost.published, originalPost.published)
        XCTAssertEqual(convertedBackPost.type, originalPost.type)
        XCTAssertEqual(convertedBackPost.voiceNotes.count, originalPost.voiceNotes.count)
    }
    
    func testDomainPostToLegacyToDomainRoundTrip() {
        // Given
        let originalDomainPost = createSampleDomainPost()
        
        // When
        let post = PostAdapter.toLegacy(originalDomainPost)
        let convertedBackDomainPost = PostAdapter.toDomain(post)
        
        // Then
        XCTAssertEqual(convertedBackDomainPost.id, originalDomainPost.id)
        XCTAssertEqual(convertedBackDomainPost.date, originalDomainPost.date)
        XCTAssertEqual(convertedBackDomainPost.goodItems, originalDomainPost.goodItems)
        XCTAssertEqual(convertedBackDomainPost.badItems, originalDomainPost.badItems)
        XCTAssertEqual(convertedBackDomainPost.published, originalDomainPost.published)
        XCTAssertEqual(convertedBackDomainPost.type, originalDomainPost.type)
        XCTAssertEqual(convertedBackDomainPost.voiceNotes.count, originalDomainPost.voiceNotes.count)
    }
    
    // MARK: - Extension Tests
    
    func testPostExtensionToDomain() {
        // Given
        let post = createSamplePost()
        
        // When
        let domainPost = post.toDomain()
        
        // Then
        XCTAssertEqual(domainPost.id, post.id)
        XCTAssertEqual(domainPost.goodItems, post.goodItems)
    }
    
    func testDomainPostExtensionToLegacy() {
        // Given
        let domainPost = createSampleDomainPost()
        
        // When
        let post = domainPost.toLegacy()
        
        // Then
        XCTAssertEqual(post.id, domainPost.id)
        XCTAssertEqual(post.goodItems, domainPost.goodItems)
    }
    
    func testPostArrayExtensionToDomain() {
        // Given
        let posts = [createSamplePost(), createSamplePost()]
        
        // When
        let domainPosts = posts.toDomain()
        
        // Then
        XCTAssertEqual(domainPosts.count, posts.count)
    }
    
    func testDomainPostArrayExtensionToLegacy() {
        // Given
        let domainPosts = [createSampleDomainPost(), createSampleDomainPost()]
        
        // When
        let posts = domainPosts.toLegacy()
        
        // Then
        XCTAssertEqual(posts.count, domainPosts.count)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyArrayConversion() {
        // Given
        let emptyPosts: [Post] = []
        let emptyDomainPosts: [DomainPost] = []
        
        // When & Then
        XCTAssertTrue(PostAdapter.toDomain(emptyPosts).isEmpty)
        XCTAssertTrue(PostAdapter.toLegacy(emptyDomainPosts).isEmpty)
    }
    
    func testPostWithNoVoiceNotes() {
        // Given
        var post = createSamplePost()
        post.voiceNotes = []
        
        // When
        let domainPost = PostAdapter.toDomain(post)
        let convertedBack = PostAdapter.toLegacy(domainPost)
        
        // Then
        XCTAssertTrue(domainPost.voiceNotes.isEmpty)
        XCTAssertTrue(convertedBack.voiceNotes.isEmpty)
    }
    
    func testPostWithNilOptionalFields() {
        // Given
        var post = createSamplePost()
        post.authorUsername = nil
        post.authorFirstName = nil
        post.authorLastName = nil
        post.externalText = nil
        post.authorId = nil
        post.isEvaluated = nil
        post.evaluationResults = nil
        
        // When
        let domainPost = PostAdapter.toDomain(post)
        let convertedBack = PostAdapter.toLegacy(domainPost)
        
        // Then
        XCTAssertNil(domainPost.authorUsername)
        XCTAssertNil(domainPost.authorFirstName)
        XCTAssertNil(domainPost.authorLastName)
        XCTAssertNil(domainPost.externalText)
        XCTAssertNil(domainPost.authorId)
        XCTAssertNil(domainPost.isEvaluated)
        XCTAssertNil(domainPost.evaluationResults)
        
        XCTAssertNil(convertedBack.authorUsername)
        XCTAssertNil(convertedBack.authorFirstName)
        XCTAssertNil(convertedBack.authorLastName)
        XCTAssertNil(convertedBack.externalText)
        XCTAssertNil(convertedBack.authorId)
        XCTAssertNil(convertedBack.isEvaluated)
        XCTAssertNil(convertedBack.evaluationResults)
    }
}
