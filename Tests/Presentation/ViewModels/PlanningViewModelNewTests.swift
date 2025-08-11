import XCTest
@testable import LazyBones

@MainActor
final class PlanningViewModelNewTests: XCTestCase {
    var vm: PlanningViewModelNew!
    var mockTags: MockTagRepository!
    var mockGet: MockGetReportsUseCase!
    var mockDel: MockDeleteReportUseCase!
    var mockUpd: MockUpdateReportUseCase!
    var mockCreate: MockCreateReportUseCase!
    var mockTg: MockPostTelegramService!

    override func setUp() {
        super.setUp()
        mockTags = MockTagRepository()
        mockGet = MockGetReportsUseCase()
        mockDel = MockDeleteReportUseCase()
        mockUpd = MockUpdateReportUseCase()
        mockCreate = MockCreateReportUseCase()
        mockTg = MockPostTelegramService()
        vm = PlanningViewModelNew(
            tagRepository: mockTags,
            getReportsUseCase: mockGet,
            deleteReportUseCase: mockDel,
            updateReportUseCase: mockUpd,
            createReportUseCase: mockCreate,
            postTelegramService: mockTg
        )
    }

    override func tearDown() {
        vm = nil
        mockTags = nil
        mockGet = nil
        mockDel = nil
        mockUpd = nil
        mockCreate = nil
        mockTg = nil
        super.tearDown()
    }

    // MARK: - savePlanAsCustomReport

    func testSavePlanAsCustomReport_EmptyPlan() async {
        // Given
        vm.planItems = [" ", "\n"]

        // When
        await vm.savePlanAsCustomReport()

        // Then
        XCTAssertEqual(vm.statusMessage, "План пуст — нечего сохранять")
        XCTAssertFalse(mockCreate.didCallExecute)
        XCTAssertFalse(mockUpd.didCallExecute)
    }

    func testSavePlanAsCustomReport_CreatesNew() async {
        // Given: нет кастомных за сегодня
        mockGet.mockCustomReports = []
        vm.planItems = ["  A  ", "B"]

        // When
        await vm.savePlanAsCustomReport()

        // Then
        XCTAssertTrue(mockCreate.didCallExecute)
        XCTAssertEqual(mockCreate.lastInput?.type, .custom)
        XCTAssertEqual(mockCreate.lastInput?.goodItems, ["A", "B"])
        XCTAssertEqual(vm.statusMessage, "План сохранён")
    }

    func testSavePlanAsCustomReport_UpdatesExisting() async {
        // Given: есть кастомный за сегодня
        var existing = DomainPost.mockCustom()
        existing.date = Date()
        mockGet.mockCustomReports = [existing]
        vm.planItems = ["C", "  D  "]

        // When
        await vm.savePlanAsCustomReport()

        // Then
        XCTAssertTrue(mockUpd.didCallExecute)
        guard let updated = mockUpd.lastInputReport else {
            return XCTFail("UpdateReportUseCase was not called with input")
        }
        XCTAssertEqual(updated.goodItems, ["C", "D"]) // обрезка пробелов
        XCTAssertEqual(updated.badItems, [])
        XCTAssertEqual(updated.published, false)
        XCTAssertEqual(vm.statusMessage, "План сохранён")
    }
}

// MARK: - Mocks used by PlanningViewModelNew tests

final class MockCreateReportUseCase: CreateReportUseCase {
    var didCallExecute = false
    var lastInput: CreateReportInput?

    init() {
        super.init(postRepository: DummyPostRepository())
    }

    override func execute(input: CreateReportInput) async throws -> DomainPost {
        didCallExecute = true
        lastInput = input
        // вернуть пост, схожий с тем, что создаёт UC
        return DomainPost(
            date: Date(),
            goodItems: input.goodItems,
            badItems: input.badItems,
            published: false,
            voiceNotes: input.voiceNotes,
            type: input.type,
            isEvaluated: input.isEvaluated,
            evaluationResults: input.evaluationResults
        )
    }
}

final class DummyPostRepository: PostRepositoryProtocol {
    func save(_ post: DomainPost) async throws {}
    func delete(_ id: UUID) async throws {}
    func update(_ post: DomainPost) async throws {}
    func load(date: Date?, type: PostType?, includeExternal: Bool) async throws -> [DomainPost] { return [] }
}

final class MockPostTelegramService: PostTelegramServiceProtocol {
    var didSendText = false
    var didSendVoice = false

    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        didSendText = true
        completion(true)
    }

    func sendVoice(fileURL: URL, caption: String?, completion: @escaping (Bool) -> Void) {
        didSendVoice = true
        completion(true)
    }
}
