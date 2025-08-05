import XCTest
@testable import LazyBones

/// Тесты для ICloudReportsViewModel
@MainActor
class ICloudReportsViewModelTests: XCTestCase {
    
    var viewModel: ICloudReportsViewModel!
    var mockICloudService: MockICloudService!
    
    override func setUp() {
        super.setUp()
        mockICloudService = MockICloudService()
        viewModel = ICloudReportsViewModel(iCloudService: mockICloudService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockICloudService = nil
        super.tearDown()
    }
    
    // MARK: - Load Reports Tests
    
    func testLoadReportsSuccess() async {
        // Given
        let mockReports = [
            DomainICloudReport(
                deviceName: "Test Device",
                deviceIdentifier: "test-id",
                reportContent: "Test content",
                reportType: .regular
            )
        ]
        mockICloudService.mockImportOutput = ImportICloudReportsOutput(
            success: true,
            reports: mockReports,
            importedCount: 1
        )
        mockICloudService.mockICloudAvailable = true
        mockICloudService.mockFileInfo = (URL(string: "file://test.report"), 1024)
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertTrue(viewModel.state.isICloudAvailable)
        XCTAssertNotNil(viewModel.state.lastRefreshDate)
    }
    
    func testLoadReportsICloudNotAvailable() async {
        // Given
        mockICloudService.mockICloudAvailable = false
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.error as? ImportICloudReportsError, .iCloudNotAvailable)
        XCTAssertFalse(viewModel.state.isICloudAvailable)
    }
    
    func testLoadReportsFailure() async {
        // Given
        mockICloudService.mockICloudAvailable = true
        mockICloudService.mockImportError = ImportICloudReportsError.fileNotFound
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.error as? ImportICloudReportsError, .fileNotFound)
    }
    
    // MARK: - Export Reports Tests
    
    func testExportReportsSuccess() async {
        // Given
        mockICloudService.mockExportOutput = ExportReportsOutput(
            success: true,
            fileURL: URL(string: "file://test.report"),
            exportedCount: 2
        )
        mockICloudService.mockFileInfo = (URL(string: "file://test.report"), 2048)
        
        // When
        await viewModel.handle(.exportReports(reportType: .today, format: .telegram))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
        XCTAssertEqual(viewModel.state.fileInfo.size, 2048)
    }
    
    func testExportReportsFailure() async {
        // Given
        mockICloudService.mockExportError = ExportReportsError.noReportsToExport
        
        // When
        await viewModel.handle(.exportReports(reportType: .today, format: .telegram))
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.error as? ExportReportsError, .noReportsToExport)
    }
    
    // MARK: - Delete File Tests
    
    func testDeleteFileSuccess() async {
        // Given
        viewModel.state.reports = [
            DomainICloudReport(
                deviceName: "Test Device",
                deviceIdentifier: "test-id",
                reportContent: "Test content",
                reportType: .regular
            )
        ]
        viewModel.state.fileInfo = (URL(string: "file://test.report"), 1024)
        viewModel.state.lastRefreshDate = Date()
        
        // When
        await viewModel.handle(.deleteFile)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.reports.isEmpty)
        XCTAssertNil(viewModel.state.fileInfo.url)
        XCTAssertNil(viewModel.state.fileInfo.size)
        XCTAssertNil(viewModel.state.lastRefreshDate)
    }
    
    func testDeleteFileFailure() async {
        // Given
        mockICloudService.mockDeleteError = ImportICloudReportsError.fileNotFound
        
        // When
        await viewModel.handle(.deleteFile)
        
        // Then
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertEqual(viewModel.state.error as? ImportICloudReportsError, .fileNotFound)
    }
    
    // MARK: - State Tests
    
    func testStateProperties() {
        // Given
        let reports = [
            DomainICloudReport(
                deviceName: "Device 1",
                deviceIdentifier: "id1",
                reportContent: "Content 1",
                reportType: .regular
            ),
            DomainICloudReport(
                deviceName: "Device 2",
                deviceIdentifier: "id2",
                reportContent: "Content 2",
                reportType: .custom
            )
        ]
        viewModel.state.reports = reports
        viewModel.state.fileInfo = (URL(string: "file://test.report"), 1024)
        viewModel.state.lastRefreshDate = Date()
        
        // Then
        XCTAssertTrue(viewModel.state.hasReports)
        XCTAssertEqual(viewModel.state.reportsCount, 2)
        XCTAssertNotEqual(viewModel.state.formattedLastRefresh, "Никогда")
        XCTAssertEqual(viewModel.state.formattedFileSize, "1 KB")
    }
    
    func testClearError() async {
        // Given
        viewModel.state.error = ImportICloudReportsError.fileNotFound
        
        // When
        await viewModel.handle(.clearError)
        
        // Then
        XCTAssertNil(viewModel.state.error)
    }
}

// MARK: - Mock ICloud Service

class MockICloudService: ICloudServiceProtocol {
    var mockICloudAvailable = true
    var mockFileInfo: (url: URL?, size: Int64?) = (nil, nil)
    var mockImportOutput: ImportICloudReportsOutput?
    var mockExportOutput: ExportReportsOutput?
    var mockImportError: Error?
    var mockExportError: Error?
    var mockDeleteError: Error?
    
    func exportReports(reportType: ICloudReportType, startDate: Date?, endDate: Date?, includeDeviceInfo: Bool, format: ReportFormat) async throws -> ExportReportsOutput {
        if let error = mockExportError {
            throw error
        }
        return mockExportOutput ?? ExportReportsOutput(success: false)
    }
    
    func importReports(reportType: ICloudReportType, startDate: Date?, endDate: Date?, filterByDevice: String?) async throws -> ImportICloudReportsOutput {
        if let error = mockImportError {
            throw error
        }
        return mockImportOutput ?? ImportICloudReportsOutput(success: false)
    }
    
    func isICloudAvailable() async -> Bool {
        return mockICloudAvailable
    }
    
    func getFileInfo() async -> (url: URL?, size: Int64?) {
        return mockFileInfo
    }
    
    func deleteFile() async throws {
        if let error = mockDeleteError {
            throw error
        }
    }
} 