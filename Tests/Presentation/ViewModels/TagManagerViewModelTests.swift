import XCTest
@testable import LazyBones

@MainActor
class TagManagerViewModelTests: XCTestCase {
    
    var viewModel: TagManagerViewModel!
    var mockStore: PostStore!
    
    override func setUp() {
        super.setUp()
        mockStore = PostStore()
        viewModel = TagManagerViewModel(store: mockStore)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_SetsDefaultValues() {
        // Given & When - в setUp()
        
        // Then
        XCTAssertEqual(viewModel.tagCategory, 0)
        XCTAssertEqual(viewModel.newTag, "")
        XCTAssertNil(viewModel.editingTagIndex)
        XCTAssertEqual(viewModel.editingTagText, "")
        XCTAssertFalse(viewModel.showDeleteTagAlert)
        XCTAssertNil(viewModel.tagToDelete)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCurrentTags_WithGoodCategory_ReturnsGoodTags() {
        // Given
        mockStore.goodTags = ["tag1", "tag2"]
        mockStore.badTags = ["bad1"]
        viewModel.tagCategory = 0
        
        // When
        let result = viewModel.currentTags
        
        // Then
        XCTAssertEqual(result, ["tag1", "tag2"])
    }
    
    func testCurrentTags_WithBadCategory_ReturnsBadTags() {
        // Given
        mockStore.goodTags = ["tag1", "tag2"]
        mockStore.badTags = ["bad1"]
        viewModel.tagCategory = 1
        
        // When
        let result = viewModel.currentTags
        
        // Then
        XCTAssertEqual(result, ["bad1"])
    }
    
    func testIsNewTagEmpty_WithEmptyTag_ReturnsTrue() {
        // Given
        viewModel.newTag = "   "
        
        // When
        let result = viewModel.isNewTagEmpty
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsNewTagEmpty_WithNonEmptyTag_ReturnsFalse() {
        // Given
        viewModel.newTag = "test"
        
        // When
        let result = viewModel.isNewTagEmpty
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Tag Management Tests
    
    func testAddTag_WithGoodCategory_AddsGoodTag() {
        // Given
        viewModel.tagCategory = 0
        viewModel.newTag = "new tag"
        
        // When
        viewModel.addTag()
        
        // Then
        XCTAssertTrue(mockStore.goodTags.contains("new tag"))
        XCTAssertEqual(viewModel.newTag, "")
    }
    
    func testAddTag_WithBadCategory_AddsBadTag() {
        // Given
        viewModel.tagCategory = 1
        viewModel.newTag = "bad tag"
        
        // When
        viewModel.addTag()
        
        // Then
        XCTAssertTrue(mockStore.badTags.contains("bad tag"))
        XCTAssertEqual(viewModel.newTag, "")
    }
    
    func testAddTag_WithEmptyTag_DoesNotAddTag() {
        // Given
        viewModel.tagCategory = 0
        viewModel.newTag = "   "
        let initialCount = mockStore.goodTags.count
        
        // When
        viewModel.addTag()
        
        // Then
        XCTAssertEqual(mockStore.goodTags.count, initialCount)
    }
    
    func testStartEditTag_SetsEditingState() {
        // Given
        mockStore.goodTags = ["tag1", "tag2"]
        viewModel.tagCategory = 0
        
        // When
        viewModel.startEditTag(1)
        
        // Then
        XCTAssertEqual(viewModel.editingTagIndex, 1)
        XCTAssertEqual(viewModel.editingTagText, "tag2")
    }
    
    func testFinishEditTag_WithGoodCategory_UpdatesGoodTag() {
        // Given
        mockStore.goodTags = ["old tag"]
        viewModel.tagCategory = 0
        viewModel.editingTagIndex = 0
        viewModel.editingTagText = "new tag"
        
        // When
        viewModel.finishEditTag()
        
        // Then
        XCTAssertTrue(mockStore.goodTags.contains("new tag"))
        XCTAssertFalse(mockStore.goodTags.contains("old tag"))
        XCTAssertNil(viewModel.editingTagIndex)
        XCTAssertEqual(viewModel.editingTagText, "")
    }
    
    func testFinishEditTag_WithBadCategory_UpdatesBadTag() {
        // Given
        mockStore.saveBadTags(["old bad tag"])
        viewModel.tagCategory = 1
        viewModel.editingTagIndex = 0
        viewModel.editingTagText = "new bad tag"
        
        // When
        viewModel.finishEditTag()
        
        // Then
        XCTAssertTrue(mockStore.badTags.contains("new bad tag"))
        XCTAssertFalse(mockStore.badTags.contains("old bad tag"))
        XCTAssertNil(viewModel.editingTagIndex)
        XCTAssertEqual(viewModel.editingTagText, "")
    }
    
    func testDeleteTag_WithGoodCategory_RemovesGoodTag() {
        // Given
        mockStore.goodTags = ["tag to delete"]
        viewModel.tagCategory = 0
        viewModel.tagToDelete = "tag to delete"
        
        // When
        viewModel.deleteTag()
        
        // Then
        XCTAssertFalse(mockStore.goodTags.contains("tag to delete"))
        XCTAssertNil(viewModel.tagToDelete)
    }
    
    func testDeleteTag_WithBadCategory_RemovesBadTag() {
        // Given
        mockStore.badTags = ["bad tag to delete"]
        viewModel.tagCategory = 1
        viewModel.tagToDelete = "bad tag to delete"
        
        // When
        viewModel.deleteTag()
        
        // Then
        XCTAssertFalse(mockStore.badTags.contains("bad tag to delete"))
        XCTAssertNil(viewModel.tagToDelete)
    }
    
    func testPrepareDeleteTag_SetsDeleteState() {
        // Given
        let tagToDelete = "test tag"
        
        // When
        viewModel.prepareDeleteTag(tagToDelete)
        
        // Then
        XCTAssertEqual(viewModel.tagToDelete, tagToDelete)
        XCTAssertTrue(viewModel.showDeleteTagAlert)
    }
    
    func testCancelDeleteTag_ClearsDeleteState() {
        // Given
        viewModel.tagToDelete = "test tag"
        viewModel.showDeleteTagAlert = true
        
        // When
        viewModel.cancelDeleteTag()
        
        // Then
        XCTAssertNil(viewModel.tagToDelete)
        XCTAssertFalse(viewModel.showDeleteTagAlert)
    }
} 