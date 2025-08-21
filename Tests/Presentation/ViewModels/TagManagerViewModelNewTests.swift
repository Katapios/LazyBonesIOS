import XCTest
@testable import LazyBones

final class TagManagerViewModelNewTests: XCTestCase {
    private var vm: TagManagerViewModelNew!
    private var repo: MockTagRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repo = MockTagRepository()
        vm = await TagManagerViewModelNew(tagRepository: repo)
    }
    
    func testLoadTags() async {
        await vm.load()
        XCTAssertEqual(vm.goodTags, repo.mockGoodTags)
        XCTAssertEqual(vm.badTags, repo.mockBadTags)
    }
    
    func testAddGoodTag() async {
        await vm.load()
        await MainActor.run { vm.selectedSegment = .good; vm.newTagText = "NewGood" }
        await vm.addNewTag()
        XCTAssertTrue(vm.goodTags.contains("NewGood"))
        XCTAssertTrue(repo.mockGoodTags.contains("NewGood"))
    }
    
    func testAddBadTag() async {
        await vm.load()
        await MainActor.run { vm.selectedSegment = .bad; vm.newTagText = "NewBad" }
        await vm.addNewTag()
        XCTAssertTrue(vm.badTags.contains("NewBad"))
        XCTAssertTrue(repo.mockBadTags.contains("NewBad"))
    }
    
    func testDeleteTag() async {
        await vm.load()
        await MainActor.run { vm.selectedSegment = .good; vm.requestDelete(segment: .good, value: vm.goodTags.first!) }
        await vm.confirmDelete()
        XCTAssertFalse(vm.goodTags.contains("Good1"))
    }
    
    func testEditTag() async {
        await vm.load()
        await MainActor.run { vm.selectedSegment = .bad; vm.startEditing(segment: .bad, oldValue: "Bad1") }
        await MainActor.run { vm.tagBeingEdited?.newValue = "Bad1Edited" }
        await vm.applyEdit()
        XCTAssertTrue(vm.badTags.contains("Bad1Edited"))
        XCTAssertFalse(vm.badTags.contains("Bad1"))
    }
}

// MARK: - Mock Repo

final class MockTagRepository: TagRepositoryProtocol {
    var mockGoodTags: [String] = ["Good1", "Good2"]
    var mockBadTags: [String] = ["Bad1", "Bad2"]
    var shouldThrowError = false
    
    func saveGoodTags(_ tags: [String]) async throws { mockGoodTags = tags }
    func saveBadTags(_ tags: [String]) async throws { mockBadTags = tags }
    func loadGoodTags() async throws -> [String] { if shouldThrowError { throw NSError(domain: "", code: -1) }; return mockGoodTags }
    func loadBadTags() async throws -> [String] { if shouldThrowError { throw NSError(domain: "", code: -1) }; return mockBadTags }
    func addGoodTag(_ tag: String) async throws { mockGoodTags.append(tag) }
    func addBadTag(_ tag: String) async throws { mockBadTags.append(tag) }
    func removeGoodTag(_ tag: String) async throws { mockGoodTags.removeAll { $0 == tag } }
    func removeBadTag(_ tag: String) async throws { mockBadTags.removeAll { $0 == tag } }
    func updateGoodTag(old: String, new: String) async throws { if let i = mockGoodTags.firstIndex(of: old) { mockGoodTags[i] = new } }
    func updateBadTag(old: String, new: String) async throws { if let i = mockBadTags.firstIndex(of: old) { mockBadTags[i] = new } }
}
