import XCTest
@testable import LazyBones

@MainActor
class PostFormViewModelTests: XCTestCase {
    
    var viewModel: PostFormViewModel!
    var mockStore: PostStore!
    
    override func setUp() {
        super.setUp()
        mockStore = PostStore()
        viewModel = PostFormViewModel(store: mockStore)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_WithNewPost_SetsDefaultValues() {
        // Given & When - в setUp()
        
        // Then
        XCTAssertEqual(viewModel.title, "Создать отчёт")
        XCTAssertNil(viewModel.post)
        XCTAssertEqual(viewModel.goodItems.count, 1)
        XCTAssertEqual(viewModel.badItems.count, 1)
        XCTAssertTrue(viewModel.goodItems.first?.text.isEmpty == true)
        XCTAssertTrue(viewModel.badItems.first?.text.isEmpty == true)
        XCTAssertTrue(viewModel.voiceNotes.isEmpty)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertNil(viewModel.sendStatus)
        XCTAssertEqual(viewModel.selectedTab, .good)
    }
    
    func testInit_WithExistingPost_LoadsPostData() {
        // Given
        let existingPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Good item 1", "Good item 2"],
            badItems: ["Bad item 1"],
            published: true,
            voiceNotes: [],
            type: .regular
        )
        
        // When
        let viewModelWithPost = PostFormViewModel(
            store: mockStore,
            title: "Edit Report",
            post: existingPost
        )
        
        // Then
        XCTAssertEqual(viewModelWithPost.title, "Edit Report")
        XCTAssertEqual(viewModelWithPost.post?.id, existingPost.id)
        XCTAssertEqual(viewModelWithPost.goodItems.count, 2)
        XCTAssertEqual(viewModelWithPost.badItems.count, 1)
        XCTAssertEqual(viewModelWithPost.goodItems[0].text, "Good item 1")
        XCTAssertEqual(viewModelWithPost.goodItems[1].text, "Good item 2")
        XCTAssertEqual(viewModelWithPost.badItems[0].text, "Bad item 1")
    }
    
    // MARK: - Computed Properties Tests
    
    func testGoodTags_ReturnsMappedTags() {
        // Given
        mockStore.goodTags = ["tag1", "tag2"]
        
        // When
        let result = viewModel.goodTags
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "tag1")
        XCTAssertEqual(result[1].text, "tag2")
        XCTAssertEqual(result[0].icon, "tag")
        XCTAssertEqual(result[0].color, .green)
    }
    
    func testBadTags_ReturnsMappedTags() {
        // Given
        mockStore.badTags = ["bad1", "bad2"]
        
        // When
        let result = viewModel.badTags
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "bad1")
        XCTAssertEqual(result[1].text, "bad2")
        XCTAssertEqual(result[0].icon, "tag")
        XCTAssertEqual(result[0].color, .red)
    }
    
    func testIsReportDone_WhenStatusDone_ReturnsTrue() {
        // Given
        mockStore.reportStatus = .sent
        
        // When
        let result = viewModel.isReportDone
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsReportDone_WhenStatusNotDone_ReturnsFalse() {
        // Given
        mockStore.reportStatus = .notStarted
        
        // When
        let result = viewModel.isReportDone
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Item Management Tests
    
    func testAddGoodItem_AddsNewItem() {
        // Given
        let initialCount = viewModel.goodItems.count
        
        // When
        viewModel.addGoodItem()
        
        // Then
        XCTAssertEqual(viewModel.goodItems.count, initialCount + 1)
        XCTAssertTrue(viewModel.goodItems.last?.text.isEmpty == true)
    }
    
    func testAddBadItem_AddsNewItem() {
        // Given
        let initialCount = viewModel.badItems.count
        
        // When
        viewModel.addBadItem()
        
        // Then
        XCTAssertEqual(viewModel.badItems.count, initialCount + 1)
        XCTAssertTrue(viewModel.badItems.last?.text.isEmpty == true)
    }
    
    func testRemoveGoodItem_RemovesItem() {
        // Given
        viewModel.addGoodItem()
        let itemToRemove = viewModel.goodItems[1]
        let initialCount = viewModel.goodItems.count
        
        // When
        viewModel.removeGoodItem(itemToRemove)
        
        // Then
        XCTAssertEqual(viewModel.goodItems.count, initialCount - 1)
        XCTAssertFalse(viewModel.goodItems.contains { $0.id == itemToRemove.id })
    }
    
    func testRemoveGoodItem_WhenLastItem_AddsEmptyItem() {
        // Given
        let itemToRemove = viewModel.goodItems[0]
        
        // When
        viewModel.removeGoodItem(itemToRemove)
        
        // Then
        XCTAssertEqual(viewModel.goodItems.count, 1)
        XCTAssertTrue(viewModel.goodItems.first?.text.isEmpty == true)
    }
    
    func testRemoveBadItem_RemovesItem() {
        // Given
        viewModel.addBadItem()
        let itemToRemove = viewModel.badItems[1]
        let initialCount = viewModel.badItems.count
        
        // When
        viewModel.removeBadItem(itemToRemove)
        
        // Then
        XCTAssertEqual(viewModel.badItems.count, initialCount - 1)
        XCTAssertFalse(viewModel.badItems.contains { $0.id == itemToRemove.id })
    }
    
    // MARK: - Tag Management Tests
    
    func testAddGoodTag_WithEmptyLastItem_UpdatesLastItem() {
        // Given
        let tag = TagItem(text: "test tag", icon: "tag", color: .green)
        let lastItem = viewModel.goodItems[0]
        
        // When
        viewModel.addGoodTag(tag)
        
        // Then
        XCTAssertEqual(viewModel.goodItems.count, 1)
        XCTAssertEqual(viewModel.goodItems[0].text, "✅ test tag")
        XCTAssertEqual(viewModel.goodItems[0].id, lastItem.id)
    }
    
    func testAddGoodTag_WithNonEmptyLastItem_AddsNewItem() {
        // Given
        viewModel.goodItems[0].text = "existing item"
        let tag = TagItem(text: "test tag", icon: "tag", color: .green)
        let initialCount = viewModel.goodItems.count
        
        // When
        viewModel.addGoodTag(tag)
        
        // Then
        XCTAssertEqual(viewModel.goodItems.count, initialCount + 1)
        XCTAssertEqual(viewModel.goodItems.last?.text, "✅ test tag")
    }
    
    func testAddBadTag_WithEmptyLastItem_UpdatesLastItem() {
        // Given
        let tag = TagItem(text: "test tag", icon: "tag", color: .red)
        let lastItem = viewModel.badItems[0]
        
        // When
        viewModel.addBadTag(tag)
        
        // Then
        XCTAssertEqual(viewModel.badItems.count, 1)
        XCTAssertEqual(viewModel.badItems[0].text, "❌ test tag")
        XCTAssertEqual(viewModel.badItems[0].id, lastItem.id)
    }
    
    // MARK: - Save and Publish Tests
    
    func testSaveAndNotify_WithValidData_CreatesPost() {
        // Given
        viewModel.goodItems[0].text = "Good item"
        viewModel.badItems[0].text = "Bad item"
        var saveCalled = false
        viewModel = PostFormViewModel(
            store: mockStore,
            onSave: { saveCalled = true }
        )
        viewModel.goodItems[0].text = "Good item"
        viewModel.badItems[0].text = "Bad item"
        
        // When
        viewModel.saveAndNotify()
        
        // Then
        XCTAssertTrue(saveCalled)
        XCTAssertEqual(mockStore.posts.count, 1)
        XCTAssertEqual(mockStore.posts[0].goodItems, ["Good item"])
        XCTAssertEqual(mockStore.posts[0].badItems, ["Bad item"])
        XCTAssertFalse(mockStore.posts[0].published)
    }
    
    func testSaveAndNotify_WithEmptyItems_FiltersEmptyItems() {
        // Given
        viewModel.goodItems[0].text = "Good item"
        viewModel.badItems[0].text = "   " // Empty after trimming
        
        // When
        viewModel.saveAndNotify()
        
        // Then
        XCTAssertEqual(mockStore.posts.count, 1)
        XCTAssertEqual(mockStore.posts[0].goodItems, ["Good item"])
        XCTAssertTrue(mockStore.posts[0].badItems.isEmpty)
    }
    
    func testPublishAndNotify_WithValidData_CreatesPublishedPost() {
        // Given
        viewModel.goodItems[0].text = "Good item"
        viewModel.badItems[0].text = "Bad item"
        var publishCalled = false
        viewModel = PostFormViewModel(
            store: mockStore,
            onPublish: { publishCalled = true }
        )
        viewModel.goodItems[0].text = "Good item"
        viewModel.badItems[0].text = "Bad item"
        
        // When
        viewModel.publishAndNotify()
        
        // Then
        XCTAssertTrue(publishCalled)
        XCTAssertEqual(mockStore.posts.count, 1)
        XCTAssertEqual(mockStore.posts[0].goodItems, ["Good item"])
        XCTAssertEqual(mockStore.posts[0].badItems, ["Bad item"])
        XCTAssertTrue(mockStore.posts[0].published)
    }
    
    func testPublishAndNotify_WithExistingPost_UpdatesPost() {
        // Given
        let existingPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Old good"],
            badItems: ["Old bad"],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        viewModel = PostFormViewModel(store: mockStore, post: existingPost)
        viewModel.goodItems[0].text = "New good"
        viewModel.badItems[0].text = "New bad"
        
        // When
        viewModel.publishAndNotify()
        
        // Then
        XCTAssertEqual(mockStore.posts.count, 1)
        XCTAssertEqual(mockStore.posts[0].goodItems, ["New good"])
        XCTAssertEqual(mockStore.posts[0].badItems, ["New bad"])
        XCTAssertTrue(mockStore.posts[0].published)
    }
} 