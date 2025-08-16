import XCTest
@testable import LazyBones

@MainActor
class CreateReportUseCaseTests: XCTestCase {
    
    var useCase: CreateReportUseCase!
    fileprivate var mockRepository: MockPostRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockPostRepository()
        useCase = CreateReportUseCase(postRepository: mockRepository)
    }
    
    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testCreateReport_Success() async throws {
        // Given
        let input = CreateReportInput(
            goodItems: ["Кодил", "Гулял"],
            badItems: ["Не спал"],
            voiceNotes: [],
            type: .regular
        )
        
        // When
        let result = try await useCase.execute(input: input)
        
        // Then
        XCTAssertEqual(result.goodItems, ["Кодил", "Гулял"])
        XCTAssertEqual(result.badItems, ["Не спал"])
        XCTAssertEqual(result.type, .regular)
        XCTAssertFalse(result.published)
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(mockRepository.savedPost?.goodItems, ["Кодил", "Гулял"])
    }
    
    func testCreateReport_EmptyReport_ThrowsError() async {
        // Given
        let input = CreateReportInput(
            goodItems: [],
            badItems: [],
            voiceNotes: [],
            type: .regular
        )
        
        // When & Then
        do {
            _ = try await useCase.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch CreateReportError.emptyReport {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateReport_WithVoiceNotes_Success() async throws {
        // Given
        let voiceNote = DomainVoiceNote(url: URL(string: "file://test.m4a")!, duration: 30.0)
        let input = CreateReportInput(
            goodItems: [],
            badItems: [],
            voiceNotes: [voiceNote],
            type: .regular
        )
        
        // When
        let result = try await useCase.execute(input: input)
        
        // Then
        XCTAssertEqual(result.voiceNotes.count, 1)
        XCTAssertEqual(result.voiceNotes.first?.duration, 30.0)
        XCTAssertTrue(mockRepository.saveCalled)
    }
    
    func testCreateReport_CustomType_Success() async throws {
        // Given
        let input = CreateReportInput(
            goodItems: ["План выполнен"],
            badItems: [],
            voiceNotes: [],
            type: .custom,
            isEvaluated: true,
            evaluationResults: [true, false, true]
        )
        
        // When
        let result = try await useCase.execute(input: input)
        
        // Then
        XCTAssertEqual(result.type, .custom)
        XCTAssertEqual(result.isEvaluated, true)
        XCTAssertEqual(result.evaluationResults, [true, false, true])
        XCTAssertTrue(mockRepository.saveCalled)
    }
    
    func testCreateReport_RepositoryError_ThrowsError() async {
        // Given
        let input = CreateReportInput(
            goodItems: ["Кодил"],
            badItems: [],
            voiceNotes: [],
            type: .regular
        )
        mockRepository.shouldThrowError = true
        
        // When & Then
        do {
            _ = try await useCase.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch CreateReportError.repositoryError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Repository

fileprivate final class MockPostRepository: PostRepositoryProtocol {
    var saveCalled = false
    var savedPost: DomainPost?
    var shouldThrowError = false
    
    func save(_ post: DomainPost) async throws {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        saveCalled = true
        savedPost = post
    }
    
    func fetch() async throws -> [DomainPost] {
        return []
    }
    
    func fetch(for date: Date) async throws -> [DomainPost] {
        return []
    }
    
    func update(_ post: DomainPost) async throws {
        // Not implemented for this test
    }
    
    func delete(_ post: DomainPost) async throws {
        // Not implemented for this test
    }
    
    func clear() async throws {
        // Not implemented for this test
    }
} 