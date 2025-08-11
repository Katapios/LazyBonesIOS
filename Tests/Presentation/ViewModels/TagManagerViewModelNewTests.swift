import XCTest
@testable import LazyBones

@MainActor
final class TagManagerViewModelNewTests: XCTestCase {
    var viewModel: TagManagerViewModelNew!
    var repo: MockTagRepository!

    override func setUp() async throws {
        try await super.setUp()
        repo = MockTagRepository()
        repo.good = ["g1", "g2"]
        repo.bad = ["b1"]
        viewModel = TagManagerViewModelNew(tagRepository: repo)
        await viewModel.loadTags()
    }

    override func tearDown() async throws {
        viewModel = nil
        repo = nil
        try await super.tearDown()
    }

    func testLoadTags_Success() async {
        XCTAssertEqual(viewModel.goodTags, ["g1", "g2"])
        XCTAssertEqual(viewModel.badTags, ["b1"])
    }

    func testAddTag_Good() async {
        viewModel.tagCategory = 0
        viewModel.newTag = " newG "
        await viewModel.addTag()
        XCTAssertEqual(repo.good, ["g1", "g2", "newG"]) // repo mutated
        XCTAssertEqual(viewModel.newTag, "")
        // view model reloaded from repo
        XCTAssertTrue(viewModel.goodTags.contains("newG"))
    }

    func testAddTag_Bad() async {
        viewModel.tagCategory = 1
        viewModel.newTag = " newB "
        await viewModel.addTag()
        XCTAssertEqual(repo.bad, ["b1", "newB"]) // repo mutated
        XCTAssertEqual(viewModel.newTag, "")
        XCTAssertTrue(viewModel.badTags.contains("newB"))
    }

    func testEditTag_Good() async {
        viewModel.tagCategory = 0
        viewModel.startEditTag(0)
        viewModel.editingTagText = "g1_edited"
        await viewModel.finishEditTag()
        XCTAssertEqual(repo.good, ["g1_edited", "g2"])
        XCTAssertNil(viewModel.editingTagIndex)
        XCTAssertEqual(viewModel.editingTagText, "")
        XCTAssertEqual(viewModel.goodTags.first, "g1_edited")
    }

    func testEditTag_Bad() async {
        viewModel.tagCategory = 1
        viewModel.startEditTag(0)
        viewModel.editingTagText = "b1_edited"
        await viewModel.finishEditTag()
        XCTAssertEqual(repo.bad, ["b1_edited"])
        XCTAssertNil(viewModel.editingTagIndex)
        XCTAssertEqual(viewModel.editingTagText, "")
        XCTAssertEqual(viewModel.badTags.first, "b1_edited")
    }

    func testDeleteTag_Good() async {
        viewModel.tagCategory = 0
        viewModel.prepareDeleteTag("g2")
        await viewModel.deleteTag()
        XCTAssertEqual(repo.good, ["g1"]) 
        XCTAssertFalse(viewModel.goodTags.contains("g2"))
    }

    func testDeleteTag_Bad() async {
        viewModel.tagCategory = 1
        viewModel.prepareDeleteTag("b1")
        await viewModel.deleteTag()
        XCTAssertEqual(repo.bad, []) 
        XCTAssertFalse(viewModel.badTags.contains("b1"))
    }

    func testHandleTagsDidChange_Reloads() async {
        // Change repo data and fire notification
        repo.good = ["x"]
        repo.bad = ["y"]
        NotificationCenter.default.post(name: .tagsDidChange, object: nil)
        // allow async Task in handler to run
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(viewModel.goodTags, ["x"])
        XCTAssertEqual(viewModel.badTags, ["y"])
    }
}

// MARK: - Mock TagRepository
final class MockTagRepository: TagRepositoryProtocol {
    var good: [String] = []
    var bad: [String] = []
    var shouldThrow = false

    func saveGoodTags(_ tags: [String]) async throws {}
    func saveBadTags(_ tags: [String]) async throws {}

    func loadGoodTags() async throws -> [String] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return good
    }
    func loadBadTags() async throws -> [String] {
        if shouldThrow { throw NSError(domain: "test", code: 2) }
        return bad
    }
    func addGoodTag(_ tag: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 3) }
        good.append(tag)
    }
    func addBadTag(_ tag: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 4) }
        bad.append(tag)
    }
    func removeGoodTag(_ tag: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 5) }
        good.removeAll { $0 == tag }
    }
    func removeBadTag(_ tag: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 6) }
        bad.removeAll { $0 == tag }
    }
    func updateGoodTag(old: String, new: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 7) }
        if let i = good.firstIndex(of: old) { good[i] = new }
    }
    func updateBadTag(old: String, new: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 8) }
        if let i = bad.firstIndex(of: old) { bad[i] = new }
    }
}
