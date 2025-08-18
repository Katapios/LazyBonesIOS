import XCTest
@testable import LazyBones

@MainActor
final class PlanningViewModelTests: XCTestCase {
    var viewModel: PlanningViewModel!
    var mockStore: PostStore!
    
    override func setUp() async throws {
        try await super.setUp()
        mockStore = PostStore()
        viewModel = PlanningViewModel(store: mockStore)
        // Очистим возможные сохранённые планы на сегодня
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockStore = nil
        try await super.tearDown()
    }
    
    // MARK: - Init & lifecycle
    
    func testInit_Defaults() {
        XCTAssertEqual(viewModel.planItems, [])
        XCTAssertEqual(viewModel.newPlanItem, "")
        XCTAssertNil(viewModel.editingPlanIndex)
        XCTAssertEqual(viewModel.editingPlanText, "")
        XCTAssertFalse(viewModel.showSaveAlert)
        XCTAssertFalse(viewModel.showDeletePlanAlert)
        XCTAssertNil(viewModel.planToDeleteIndex)
        XCTAssertNotNil(viewModel.lastPlanDate)
        XCTAssertNil(viewModel.publishStatus)
        XCTAssertEqual(viewModel.pickerIndex, 0)
        XCTAssertFalse(viewModel.showTagPicker)
    }
    
    func testOnAppear_LoadsTagsSettingsAndPlan() {
        // Given
        mockStore.goodTags = []
        // When
        viewModel.onAppear()
        // Then
        // Проверим, что lastPlanDate установлен на начало текущего дня
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(viewModel.lastPlanDate, expected)
        // planItems должен загрузиться (по умолчанию пустой)
        XCTAssertEqual(viewModel.planItems, [])
    }
    
    // MARK: - Actions: add/edit/delete
    
    func testAddPlanItem_AppendsTrimmedAndClearsInput() {
        // Given
        viewModel.newPlanItem = "  task  "
        // When
        viewModel.addPlanItem()
        // Then
        XCTAssertEqual(viewModel.planItems, ["task"])
        XCTAssertEqual(viewModel.newPlanItem, "")
    }
    
    func testAddPlanItem_EmptyIgnored() {
        viewModel.newPlanItem = "   "
        viewModel.addPlanItem()
        XCTAssertTrue(viewModel.planItems.isEmpty)
    }
    
    func testStartEdit_SetsIndexAndText() {
        viewModel.planItems = ["one", "two"]
        viewModel.startEditPlanItem(1)
        XCTAssertEqual(viewModel.editingPlanIndex, 1)
        XCTAssertEqual(viewModel.editingPlanText, "two")
    }
    
    func testFinishEdit_UpdatesAndResetsState() {
        viewModel.planItems = ["one", "two"]
        viewModel.startEditPlanItem(1)
        viewModel.editingPlanText = "two updated"
        viewModel.finishEditPlanItem()
        XCTAssertEqual(viewModel.planItems, ["one", "two updated"])
        XCTAssertNil(viewModel.editingPlanIndex)
        XCTAssertEqual(viewModel.editingPlanText, "")
    }
    
    func testDeletePlanItem_RemovesItem() {
        viewModel.planItems = ["one", "two", "three"]
        viewModel.planToDeleteIndex = 1
        viewModel.deletePlanItem()
        XCTAssertEqual(viewModel.planItems, ["one", "three"])
        XCTAssertNil(viewModel.planToDeleteIndex)
    }
    
    // MARK: - Persistence: save/load
    
    func testSaveAndLoadPlan_PersistsTodayKey() {
        // Given
        viewModel.planItems = ["a", "b"]
        // When
        viewModel.savePlan()
        viewModel.planItems = []
        viewModel.loadPlan()
        // Then
        XCTAssertEqual(viewModel.planItems, ["a", "b"])
    }
    
    func testHandleDayChangeIfNeeded_ClearsOnNewDay() {
        viewModel.planItems = ["x"]
        // Смоделируем прошлый день
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            viewModel.lastPlanDate = Calendar.current.startOfDay(for: yesterday)
        }
        viewModel.handleDayChangeIfNeeded()
        XCTAssertEqual(viewModel.planItems, [])
        XCTAssertEqual(viewModel.lastPlanDate, Calendar.current.startOfDay(for: Date()))
    }
    
    // MARK: - Publish
    
    func testPublishCustomReportToTelegram_NoReport_ShowsPrompt() {
        viewModel.publishCustomReportToTelegram()
        XCTAssertEqual(viewModel.publishStatus, "Сначала сохраните план как отчет!")
    }
    
    func testPublishCustomReportToTelegram_NotEvaluated_ShowsPrompt() {
        // Given: сохраним план как отчет, но без оценки
        viewModel.planItems = ["t1"]
        viewModel.savePlanAsReport()
        // When
        viewModel.publishCustomReportToTelegram()
        // Then
        XCTAssertEqual(viewModel.publishStatus, "Сначала оцените план!")
    }
    
    func testPublishCustomReportToTelegram_SuccessSetsStatus() async {
        // Given: создадим кастомный пост и отметим оцененным
        viewModel.planItems = ["t1"]
        viewModel.savePlanAsReport()
        // Обновим пост и пометим как оцененный
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = mockStore.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            var post = mockStore.posts[idx]
            post.isEvaluated = true
            mockStore.posts[idx] = post
        }
        // When
        let exp = expectation(description: "sendToTelegram")
        // Обернём вызов в небольшой задержке ожидания завершения коллбэка
        viewModel.publishCustomReportToTelegram()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 2.0)
        // Then: статус должен быть либо успех, либо сообщение об ошибке токена/чат id
        XCTAssertNotNil(viewModel.publishStatus)
        XCTAssertTrue(["План успешно опубликован!", "Ошибка отправки: неверный токен или chat_id"].contains(viewModel.publishStatus!))
    }
}
