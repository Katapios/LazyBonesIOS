import XCTest
@testable import LazyBones

/// Интеграционные тесты для iCloud системы
class ICloudIntegrationTests: XCTestCase {
    
    var dependencyContainer: DependencyContainer!
    var iCloudService: ICloudServiceProtocol!
    var postRepository: PostRepositoryProtocol!
    
    override func setUp() {
        super.setUp()
        
        // Используем shared контейнер
        dependencyContainer = DependencyContainer.shared
        
        // Регистрируем моки вместо реальных сервисов
        registerMockServices()
        
        // Получаем сервисы
        iCloudService = dependencyContainer.resolve(ICloudServiceProtocol.self)!
        postRepository = dependencyContainer.resolve(PostRepositoryProtocol.self)!
    }
    
    override func tearDown() {
        dependencyContainer.clear()
        dependencyContainer = nil
        iCloudService = nil
        postRepository = nil
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testFullExportImportCycle() async throws {
        // Given: Создаем тестовые отчеты
        let testReports = [
            DomainPost(
                date: Date(),
                goodItems: ["Тест хорошего дела 1", "Тест хорошего дела 2"],
                badItems: ["Тест плохого дела 1"],
                published: true,
                type: .regular
            ),
            DomainPost(
                date: Date(),
                goodItems: ["План на день 1", "План на день 2"],
                badItems: [],
                published: true,
                type: .custom
            )
        ]
        
        // Сохраняем отчеты
        for report in testReports {
            try await postRepository.save(report)
        }
        
        // When: Экспортируем отчеты
        let exportOutput = try await iCloudService.exportReports(
            reportType: .today,
            startDate: nil,
            endDate: nil,
            includeDeviceInfo: true,
            format: .telegram
        )
        
        // Then: Проверяем успешность экспорта
        XCTAssertTrue(exportOutput.success)
        XCTAssertEqual(exportOutput.exportedCount, 2)
        XCTAssertNotNil(exportOutput.fileURL)
        
        // When: Импортируем отчеты
        let importOutput = try await iCloudService.importReports(
            reportType: .today,
            startDate: nil,
            endDate: nil,
            filterByDevice: nil
        )
        
        // Then: Проверяем успешность импорта
        XCTAssertTrue(importOutput.success)
        XCTAssertEqual(importOutput.importedCount, 2)
        XCTAssertEqual(importOutput.reports.count, 2)
        
        // Проверяем содержимое отчетов
        let importedReports = importOutput.reports
        XCTAssertEqual(importedReports[0].reportType, .regular)
        XCTAssertEqual(importedReports[1].reportType, .custom)
    }
    
    func testExportWithNoReports() async {
        // Given: Очищаем все отчеты
        try? await postRepository.clear()
        
        // When & Then: Пытаемся экспортировать отчеты
        do {
            _ = try await iCloudService.exportReports(
                reportType: .today,
                startDate: nil,
                endDate: nil,
                includeDeviceInfo: true,
                format: .telegram
            )
            XCTFail("Expected error to be thrown")
        } catch {
            if case .some(.noReportsToExport) = (error as? ExportReportsError) {
                // ok
            } else {
                XCTFail("Expected ExportReportsError.noReportsToExport, got: \(error)")
            }
        }
    }
    
    func testImportWithNoReports() async {
        // Given: Файл пуст (мок возвращает пустой результат)
        let mockRepository = dependencyContainer.resolve(ICloudReportRepositoryProtocol.self) as! MockICloudReportRepository
        mockRepository.mockContent = ""
        
        // When & Then: Пытаемся импортировать отчеты
        do {
            _ = try await iCloudService.importReports(
                reportType: .today,
                startDate: nil,
                endDate: nil,
                filterByDevice: nil
            )
            XCTFail("Expected error to be thrown")
        } catch {
            if case .some(.noReportsFound) = (error as? ImportICloudReportsError) {
                // ok
            } else {
                XCTFail("Expected ImportICloudReportsError.noReportsFound, got: \(error)")
            }
        }
    }
    
    func testICloudNotAvailable() async {
        // Given: iCloud недоступен
        let mockRepository = dependencyContainer.resolve(ICloudReportRepositoryProtocol.self) as! MockICloudReportRepository
        mockRepository.mockICloudAvailable = false
        
        // When
        let isAvailable = await iCloudService.isICloudAvailable()
        
        // Then
        XCTAssertFalse(isAvailable)
    }
    
    func testFileInfoRetrieval() async {
        // Given: Настраиваем мок для возврата информации о файле
        let mockRepository = dependencyContainer.resolve(ICloudReportRepositoryProtocol.self) as! MockICloudReportRepository
        mockRepository.mockFileURL = URL(string: "file://test.report")
        mockRepository.mockFileSize = 2048
        
        // When
        let fileInfo = await iCloudService.getFileInfo()
        
        // Then
        XCTAssertNotNil(fileInfo.url)
        XCTAssertEqual(fileInfo.size, 2048)
    }
    
    // MARK: - Helper Methods
    
    private func registerMockServices() {
        // Регистрируем моки вместо реальных сервисов
        dependencyContainer.register(MockICloudFileManager.self, factory: {
            return MockICloudFileManager()
        })
        
        dependencyContainer.register(ReportFormatterProtocol.self, factory: {
            return MockReportFormatter()
        })
        
        let mockRepo = MockICloudReportRepository()
        dependencyContainer.register(ICloudReportRepositoryProtocol.self, instance: mockRepo)
        
        let mockDataSource = ICloud_MockPostDataSource()
        let mockPostRepository = MockPostRepository(dataSource: mockDataSource)
        dependencyContainer.register(PostRepositoryProtocol.self, instance: mockPostRepository)
        
        dependencyContainer.register(ExportReportsUseCase.self, factory: {
            let postRepository = self.dependencyContainer.resolve(PostRepositoryProtocol.self)!
            let iCloudRepository = self.dependencyContainer.resolve(ICloudReportRepositoryProtocol.self)!
            let formatter = self.dependencyContainer.resolve(ReportFormatterProtocol.self)!
            return ExportReportsUseCase(
                postRepository: postRepository,
                iCloudReportRepository: iCloudRepository,
                reportFormatter: formatter
            )
        })
        
        dependencyContainer.register(ImportICloudReportsUseCase.self, factory: {
            let iCloudRepository = self.dependencyContainer.resolve(ICloudReportRepositoryProtocol.self)!
            let formatter = self.dependencyContainer.resolve(ReportFormatterProtocol.self)!
            return ImportICloudReportsUseCase(
                iCloudReportRepository: iCloudRepository,
                reportFormatter: formatter
            )
        })
        
        dependencyContainer.register(ICloudServiceProtocol.self, factory: {
            let exportUseCase = self.dependencyContainer.resolve(ExportReportsUseCase.self)!
            let importUseCase = self.dependencyContainer.resolve(ImportICloudReportsUseCase.self)!
            let iCloudRepository = self.dependencyContainer.resolve(ICloudReportRepositoryProtocol.self)!
            return ICloudService(
                exportUseCase: exportUseCase,
                importUseCase: importUseCase,
                iCloudReportRepository: iCloudRepository
            )
        })
    }
}

// MARK: - Mock Classes

class MockICloudFileManager: ICloudFileManager {
    var mockICloudAvailable = true
    var mockContent = "Test content"
    var mockError: Error?
    
    override func isICloudAvailable() -> Bool {
        return mockICloudAvailable
    }
    
    override func saveContent(_ content: String, append: Bool = false) async throws -> URL {
        if let error = mockError {
            throw error
        }
        return URL(string: "file://test.report")!
    }
    
    override func readContent() async throws -> String {
        if let error = mockError {
            throw error
        }
        return mockContent
    }
}

class MockReportFormatter: ReportFormatterProtocol {
    func formatReports(reports: [DomainPost], format: ReportFormat, includeDeviceInfo: Bool) async throws -> String {
        return "Mock formatted content"
    }
    
    func parseReports(from content: String) async throws -> [DomainICloudReport] {
        if content.isEmpty {
            throw ImportICloudReportsError.noReportsFound
        }
        
        let now = Date()
        return [
            DomainICloudReport(
                date: now,
                deviceName: "Test Device",
                deviceIdentifier: "test-id-1",
                reportContent: "Report 1",
                reportType: .regular,
                timestamp: now
            ),
            DomainICloudReport(
                date: now.addingTimeInterval(-60),
                deviceName: "Test Device",
                deviceIdentifier: "test-id-2",
                reportContent: "Report 2",
                reportType: .custom,
                timestamp: now.addingTimeInterval(-60)
            )
        ]
    }
    
    func formatSingleReport(_ report: DomainPost) -> String {
        return "Mock single report"
    }
    
    func createReportSeparator() -> String {
        return "\n---\n"
    }
}

class ICloud_MockPostDataSource: PostDataSourceProtocol {
    private var posts: [Post] = []
    
    func save(_ posts: [Post]) async throws {
        self.posts = posts
    }
    
    func load() async throws -> [Post] {
        return posts
    }
    
    func clear() async throws {
        posts.removeAll()
    }
}

fileprivate final class MockPostRepository: PostRepositoryProtocol {
    private let dataSource: PostDataSourceProtocol
    
    init(dataSource: PostDataSourceProtocol) {
        self.dataSource = dataSource
    }
    
    func save(_ post: DomainPost) async throws {
        let dataPost = PostMapper.toDataModel(post)
        let posts = try await dataSource.load()
        var updatedPosts = posts
        updatedPosts.append(dataPost)
        try await dataSource.save(updatedPosts)
    }
    
    func fetch() async throws -> [DomainPost] {
        let posts = try await dataSource.load()
        return PostMapper.toDomainModels(posts)
    }
    
    func fetch(for date: Date) async throws -> [DomainPost] {
        let allPosts = try await fetch()
        return allPosts.filter { post in
            Calendar.current.isDate(post.date, inSameDayAs: date)
        }
    }
    
    func update(_ post: DomainPost) async throws {
        let dataPost = PostMapper.toDataModel(post)
        let posts = try await dataSource.load()
        var updatedPosts = posts
        if let index = updatedPosts.firstIndex(where: { $0.id == dataPost.id }) {
            updatedPosts[index] = dataPost
            try await dataSource.save(updatedPosts)
        }
    }
    
    func delete(_ post: DomainPost) async throws {
        let posts = try await dataSource.load()
        let filteredPosts = posts.filter { $0.id != post.id }
        try await dataSource.save(filteredPosts)
    }
    
    func clear() async throws {
        try await dataSource.clear()
    }
} 