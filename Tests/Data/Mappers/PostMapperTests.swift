import XCTest
@testable import LazyBones

@MainActor
class PostMapperTests: XCTestCase {
    
    func testToDataModel() {
        // Given
        let domainPost = DomainPost(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил", "Гулял"],
            badItems: ["Не спал"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        
        // When
        let dataPost = PostMapper.toDataModel(domainPost)
        
        // Then
        XCTAssertEqual(dataPost.id, domainPost.id)
        XCTAssertEqual(dataPost.date, domainPost.date)
        XCTAssertEqual(dataPost.goodItems, domainPost.goodItems)
        XCTAssertEqual(dataPost.badItems, domainPost.badItems)
        XCTAssertEqual(dataPost.published, domainPost.published)
        XCTAssertEqual(dataPost.type, domainPost.type)
    }
    
    func testToDomainModel() {
        // Given
        let dataPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Кодил", "Гулял"],
            badItems: ["Не спал"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        
        // When
        let domainPost = PostMapper.toDomainModel(dataPost)
        
        // Then
        XCTAssertEqual(domainPost.id, dataPost.id)
        XCTAssertEqual(domainPost.date, dataPost.date)
        XCTAssertEqual(domainPost.goodItems, dataPost.goodItems)
        XCTAssertEqual(domainPost.badItems, dataPost.badItems)
        XCTAssertEqual(domainPost.published, dataPost.published)
        XCTAssertEqual(domainPost.type, dataPost.type)
    }
    
    func testToDomainModels() {
        // Given
        let dataPosts = [
            Post(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular),
            Post(id: UUID(), date: Date(), goodItems: ["Гулял"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        
        // When
        let domainPosts = PostMapper.toDomainModels(dataPosts)
        
        // Then
        XCTAssertEqual(domainPosts.count, dataPosts.count)
        XCTAssertEqual(domainPosts[0].goodItems, dataPosts[0].goodItems)
        XCTAssertEqual(domainPosts[1].goodItems, dataPosts[1].goodItems)
    }
    
    func testToDataModels() {
        // Given
        let domainPosts = [
            DomainPost(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular),
            DomainPost(id: UUID(), date: Date(), goodItems: ["Гулял"], badItems: [], published: true, voiceNotes: [], type: .custom)
        ]
        
        // When
        let dataPosts = PostMapper.toDataModels(domainPosts)
        
        // Then
        XCTAssertEqual(dataPosts.count, domainPosts.count)
        XCTAssertEqual(dataPosts[0].goodItems, domainPosts[0].goodItems)
        XCTAssertEqual(dataPosts[1].goodItems, domainPosts[1].goodItems)
    }
} 