import XCTest
@testable import LazyBones

@MainActor
class ReportsViewModelTests: XCTestCase {
    
    var viewModel: ReportsViewModel!
    var mockStore: PostStore!
    
    override func setUp() {
        super.setUp()
        // Изолируем состояние UserDefaults для ключа переоценки
        UserDefaults.standard.removeObject(forKey: "allowCustomReportReevaluation")
        mockStore = PostStore()
        viewModel = ReportsViewModel(store: mockStore)
    }
    
    override func tearDown() {
        // Чистим ключ, чтобы не влиять на другие тесты
        UserDefaults.standard.removeObject(forKey: "allowCustomReportReevaluation")
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_LoadsReevaluationSettings() {
        // Given
        UserDefaults.standard.set(true, forKey: "allowCustomReportReevaluation")
        
        // When
        let newViewModel = ReportsViewModel(store: mockStore)
        
        // Then
        XCTAssertTrue(newViewModel.allowCustomReportReevaluation)
    }
    
    // MARK: - Computed Properties Tests
    
    func testRegularPosts_FiltersCorrectly() {
        // Given
        let regularPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        let customPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .custom)
        mockStore.posts = [regularPost, customPost]
        
        // When
        let regularPosts = viewModel.regularPosts
        
        // Then
        XCTAssertEqual(regularPosts.count, 1)
        XCTAssertEqual(regularPosts.first?.type, .regular)
    }
    
    func testCustomPosts_FiltersCorrectly() {
        // Given
        let regularPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        let customPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .custom)
        mockStore.posts = [regularPost, customPost]
        
        // When
        let customPosts = viewModel.customPosts
        
        // Then
        XCTAssertEqual(customPosts.count, 1)
        XCTAssertEqual(customPosts.first?.type, .custom)
    }
    
    func testHasRegularPosts_ReturnsTrue_WhenRegularPostsExist() {
        // Given
        let regularPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [regularPost]
        
        // When
        let hasRegular = viewModel.hasRegularPosts
        
        // Then
        XCTAssertTrue(hasRegular)
    }
    
    func testHasRegularPosts_ReturnsFalse_WhenNoRegularPosts() {
        // Given
        let customPost = Post(id: UUID(), date: Date(), goodItems: ["Test"], badItems: [], published: false, voiceNotes: [], type: .custom)
        mockStore.posts = [customPost]
        
        // When
        let hasRegular = viewModel.hasRegularPosts
        
        // Then
        XCTAssertFalse(hasRegular)
    }
    
    // MARK: - Selection Tests
    
    func testToggleSelection_AddsId_WhenNotSelected() {
        // Given
        let postId = UUID()
        
        // When
        viewModel.toggleSelection(for: postId)
        
        // Then
        XCTAssertTrue(viewModel.selectedLocalReportIDs.contains(postId))
    }
    
    func testToggleSelection_RemovesId_WhenAlreadySelected() {
        // Given
        let postId = UUID()
        viewModel.selectedLocalReportIDs.insert(postId)
        
        // When
        viewModel.toggleSelection(for: postId)
        
        // Then
        XCTAssertFalse(viewModel.selectedLocalReportIDs.contains(postId))
    }
    
    func testSelectAllRegularReports_SelectsAll_WhenNoneSelected() {
        // Given
        let post1 = Post(id: UUID(), date: Date(), goodItems: ["Test1"], badItems: [], published: false, voiceNotes: [], type: .regular)
        let post2 = Post(id: UUID(), date: Date(), goodItems: ["Test2"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [post1, post2]
        
        // When
        viewModel.selectAllRegularReports()
        
        // Then
        XCTAssertEqual(viewModel.selectedLocalReportIDs.count, 2)
        XCTAssertTrue(viewModel.selectedLocalReportIDs.contains(post1.id))
        XCTAssertTrue(viewModel.selectedLocalReportIDs.contains(post2.id))
    }
    
    func testSelectAllRegularReports_DeselectsAll_WhenAllSelected() {
        // Given
        let post1 = Post(id: UUID(), date: Date(), goodItems: ["Test1"], badItems: [], published: false, voiceNotes: [], type: .regular)
        let post2 = Post(id: UUID(), date: Date(), goodItems: ["Test2"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockStore.posts = [post1, post2]
        viewModel.selectedLocalReportIDs = Set([post1.id, post2.id])
        
        // When
        viewModel.selectAllRegularReports()
        
        // Then
        XCTAssertTrue(viewModel.selectedLocalReportIDs.isEmpty)
    }
    
    // MARK: - Selection Mode Tests
    
    func testToggleSelectionMode_TogglesMode() {
        // Given
        XCTAssertFalse(viewModel.isSelectionMode)
        
        // When
        viewModel.toggleSelectionMode()
        
        // Then
        XCTAssertTrue(viewModel.isSelectionMode)
    }
    
    func testToggleSelectionMode_ClearsSelection_WhenDisabling() {
        // Given
        let postId = UUID()
        viewModel.selectedLocalReportIDs.insert(postId)
        viewModel.isSelectionMode = true
        
        // When
        viewModel.toggleSelectionMode()
        
        // Then
        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertTrue(viewModel.selectedLocalReportIDs.isEmpty)
    }
    
    // MARK: - Evaluation Tests
    
    func testCanEvaluateReport_ReturnsTrue_ForValidReport() {
        // Given
        let today = Date()
        let post = Post(id: UUID(), date: today, goodItems: ["Task 1", "Task 2"], badItems: [], published: false, voiceNotes: [], type: .custom)
        
        // When
        let canEvaluate = viewModel.canEvaluateReport(post)
        
        // Then
        XCTAssertTrue(canEvaluate)
    }
    
    func testCanEvaluateReport_ReturnsFalse_WhenInSelectionMode() {
        // Given
        let today = Date()
        let post = Post(id: UUID(), date: today, goodItems: ["Task 1"], badItems: [], published: false, voiceNotes: [], type: .custom)
        viewModel.isSelectionMode = true
        
        // When
        let canEvaluate = viewModel.canEvaluateReport(post)
        
        // Then
        XCTAssertFalse(canEvaluate)
    }
    
    func testCanEvaluateReport_ReturnsFalse_WhenNoGoodItems() {
        // Given
        let today = Date()
        let post = Post(id: UUID(), date: today, goodItems: [], badItems: [], published: false, voiceNotes: [], type: .custom)
        
        // When
        let canEvaluate = viewModel.canEvaluateReport(post)
        
        // Then
        XCTAssertFalse(canEvaluate)
    }
    
    func testCompleteEvaluation_UpdatesPost() {
        // Given
        let post = Post(id: UUID(), date: Date(), goodItems: ["Task 1", "Task 2"], badItems: [], published: false, voiceNotes: [], type: .custom)
        mockStore.posts = [post]
        viewModel.evaluatingPost = post
        
        // When
        viewModel.completeEvaluation(results: [true, false])
        
        // Then
        XCTAssertTrue(mockStore.posts.first?.isEvaluated == true)
        XCTAssertEqual(mockStore.posts.first?.evaluationResults, [true, false])
        XCTAssertFalse(viewModel.showEvaluationSheet)
        XCTAssertNil(viewModel.evaluatingPost)
    }
    
    // MARK: - Computed Properties Tests
    
    func testSelectedReportsCount_ReturnsCorrectCount() {
        // Given
        let postId1 = UUID()
        let postId2 = UUID()
        viewModel.selectedLocalReportIDs = Set([postId1, postId2])
        
        // When
        let count = viewModel.selectedReportsCount
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func testHasSelectedReports_ReturnsTrue_WhenReportsSelected() {
        // Given
        let postId = UUID()
        viewModel.selectedLocalReportIDs.insert(postId)
        
        // When
        let hasSelected = viewModel.hasSelectedReports
        
        // Then
        XCTAssertTrue(hasSelected)
    }
    
    func testHasSelectedReports_ReturnsFalse_WhenNoReportsSelected() {
        // When
        let hasSelected = viewModel.hasSelectedReports
        
        // Then
        XCTAssertFalse(hasSelected)
    }
    
    func testCanDeleteReports_ReturnsTrue_WhenInSelectionModeAndHasSelected() {
        // Given
        let postId = UUID()
        viewModel.isSelectionMode = true
        viewModel.selectedLocalReportIDs.insert(postId)
        
        // When
        let canDelete = viewModel.canDeleteReports
        
        // Then
        XCTAssertTrue(canDelete)
    }
    
    func testCanDeleteReports_ReturnsFalse_WhenNotInSelectionMode() {
        // Given
        let postId = UUID()
        viewModel.selectedLocalReportIDs.insert(postId)
        
        // When
        let canDelete = viewModel.canDeleteReports
        
        // Then
        XCTAssertFalse(canDelete)
    }
    
    func testCanDeleteReports_ReturnsFalse_WhenNoReportsSelected() {
        // Given
        viewModel.isSelectionMode = true
        
        // When
        let canDelete = viewModel.canDeleteReports
        
        // Then
        XCTAssertFalse(canDelete)
    }
    
    // MARK: - Settings Tests
    
    func testUpdateReevaluationSettings_UpdatesSettings() {
        // Given
        XCTAssertFalse(viewModel.allowCustomReportReevaluation)
        
        // When
        viewModel.updateReevaluationSettings(true)
        
        // Then
        XCTAssertTrue(viewModel.allowCustomReportReevaluation)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "allowCustomReportReevaluation"))
    }
} 