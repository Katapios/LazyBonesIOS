import XCTest
@testable import LazyBones

/// Тесты для iCloud сервисов
class ICloudServiceTests: XCTestCase {
    
    var iCloudService: ICloudServiceProtocol!
    var mockExportUseCase: MockExportReportsUseCase!
    var mockImportUseCase: MockImportICloudReportsUseCase!
    var mockRepository: MockICloudReportRepository!
    
    override func setUp() {
        super.setUp()
        
        mockExportUseCase = MockExportReportsUseCase()
        mockImportUseCase = MockImportICloudReportsUseCase()
        mockRepository = MockICloudReportRepository()
        
        iCloudService = ICloudService(
            exportUseCase: mockExportUseCase,
            importUseCase: mockImportUseCase,
            iCloudReportRepository: mockRepository
        )
    }
    
    override func tearDown() {
        iCloudService = nil
        mockExportUseCase = nil
        mockImportUseCase = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Export Tests
    
    func testExportReportsSuccess() async throws {
        // Given
        let expectedOutput = ExportReportsOutput(
            success: true,
            fileURL: URL(string: "file://test.report"),
            exportedCount: 2
        )
        mockExportUseCase.mockOutput = expectedOutput
        
        // When
        let result = try await iCloudService.exportReports(
            reportType: .today,
            startDate: nil,
            endDate: nil,
            includeDeviceInfo: true,
            format: .telegram
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.exportedCount, 2)
        XCTAssertNotNil(result.fileURL)
    }
    
    func testExportReportsFailure() async {
        // Given
        mockExportUseCase.mockError = ExportReportsError.noReportsToExport
        
        // When & Then
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
            XCTAssertEqual(error as? ExportReportsError, .noReportsToExport)
        }
    }
    
    // MARK: - Import Tests
    
    func testImportReportsSuccess() async throws {
        // Given
        let mockReports = [
            DomainICloudReport(
                deviceName: "Test Device",
                deviceIdentifier: "test-id",
                reportContent: "Test content",
                reportType: .regular
            )
        ]
        let expectedOutput = ImportICloudReportsOutput(
            success: true,
            reports: mockReports,
            importedCount: 1
        )
        mockImportUseCase.mockOutput = expectedOutput
        
        // When
        let result = try await iCloudService.importReports(
            reportType: .today,
            startDate: nil,
            endDate: nil,
            filterByDevice: nil
        )
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.reports.count, 1)
    }
    
    func testImportReportsFailure() async {
        // Given
        mockImportUseCase.mockError = ImportICloudReportsError.fileNotFound
        
        // When & Then
        do {
            _ = try await iCloudService.importReports(
                reportType: .today,
                startDate: nil,
                endDate: nil,
                filterByDevice: nil
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? ImportICloudReportsError, .fileNotFound)
        }
    }
    
    // MARK: - iCloud Availability Tests
    
    func testIsICloudAvailable() async {
        // Given
        mockRepository.mockICloudAvailable = true
        
        // When
        let result = await iCloudService.isICloudAvailable()
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testIsICloudNotAvailable() async {
        // Given
        mockRepository.mockICloudAvailable = false
        
        // When
        let result = await iCloudService.isICloudAvailable()
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - File Info Tests
    
    func testGetFileInfo() async {
        // Given
        let mockURL = URL(string: "file://test.report")
        let mockSize: Int64 = 1024
        mockRepository.mockFileURL = mockURL
        mockRepository.mockFileSize = mockSize
        
        // When
        let result = await iCloudService.getFileInfo()
        
        // Then
        XCTAssertEqual(result.url, mockURL)
        XCTAssertEqual(result.size, mockSize)
    }
}

// MARK: - Mock Classes

class MockExportReportsUseCase: ExportReportsUseCaseProtocol {
    var mockOutput: ExportReportsOutput?
    var mockError: ExportReportsError?
    
    func execute(input: ExportReportsInput) async throws -> ExportReportsOutput {
        if let error = mockError {
            throw error
        }
        return mockOutput ?? ExportReportsOutput(success: false)
    }
}

class MockImportICloudReportsUseCase: ImportICloudReportsUseCaseProtocol {
    var mockOutput: ImportICloudReportsOutput?
    var mockError: ImportICloudReportsError?
    
    func execute(input: ImportICloudReportsInput) async throws -> ImportICloudReportsOutput {
        if let error = mockError {
            throw error
        }
        return mockOutput ?? ImportICloudReportsOutput(success: false)
    }
}

class MockICloudReportRepository: ICloudReportRepositoryProtocol {
    var mockICloudAvailable = true
    var mockFileURL: URL?
    var mockFileSize: Int64?
    var mockContent = "Test content"
    var mockError: Error?
    
    func saveToICloud(content: String, append: Bool) async throws -> URL {
        if let error = mockError {
            throw error
        }
        return mockFileURL ?? URL(string: "file://test.report")!
    }
    
    func readFromICloud() async throws -> String {
        if let error = mockError {
            throw error
        }
        return mockContent
    }
    
    func isICloudAvailable() async -> Bool {
        return mockICloudAvailable
    }
    
    func getICloudFileURL() async -> URL? {
        return mockFileURL
    }
    
    func deleteICloudFile() async throws {
        if let error = mockError {
            throw error
        }
    }
    
    func getFileSize() async -> Int64? {
        return mockFileSize
    }
} 