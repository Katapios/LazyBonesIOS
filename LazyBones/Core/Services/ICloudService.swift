import Foundation
import UIKit

/// Протокол для iCloud сервиса
protocol ICloudServiceProtocol {
    /// Экспортировать отчеты в iCloud
    func exportReports(
        reportType: ICloudReportType,
        startDate: Date?,
        endDate: Date?,
        includeDeviceInfo: Bool,
        format: ReportFormat
    ) async throws -> ExportReportsOutput
    
    /// Импортировать отчеты из iCloud
    func importReports(
        reportType: ICloudReportType,
        startDate: Date?,
        endDate: Date?,
        filterByDevice: String?
    ) async throws -> ImportICloudReportsOutput
    
    /// Проверить доступность iCloud
    func isICloudAvailable() async -> Bool
    
    /// Получить информацию о файле отчетов
    func getFileInfo() async -> (url: URL?, size: Int64?)
    
    /// Удалить файл отчетов
    func deleteFile() async throws
    
    /// Получить информацию о расположении файла
    func getFileLocationInfo() -> String
    
    /// Запросить доступ к iCloud Drive
    func requestICloudAccess() async -> Bool
    
    /// Запросить разрешения на доступ к файлам
    func requestFileAccessPermissions() async -> Bool
}

/// Основной сервис для работы с iCloud отчетами
class ICloudService: ICloudServiceProtocol {
    
    private let exportUseCase: any ExportReportsUseCaseProtocol
    private let importUseCase: any ImportICloudReportsUseCaseProtocol
    private let iCloudReportRepository: any ICloudReportRepositoryProtocol
    
    init(
        exportUseCase: any ExportReportsUseCaseProtocol,
        importUseCase: any ImportICloudReportsUseCaseProtocol,
        iCloudReportRepository: any ICloudReportRepositoryProtocol
    ) {
        self.exportUseCase = exportUseCase
        self.importUseCase = importUseCase
        self.iCloudReportRepository = iCloudReportRepository
    }
    
    // MARK: - ICloudServiceProtocol
    
    func exportReports(
        reportType: ICloudReportType,
        startDate: Date?,
        endDate: Date?,
        includeDeviceInfo: Bool,
        format: ReportFormat
    ) async throws -> ExportReportsOutput {
        Logger.info("ICloudService: Starting export with type \(reportType)", log: Logger.general)
        
        let input = ExportReportsInput(
            reportType: reportType,
            startDate: startDate,
            endDate: endDate,
            includeDeviceInfo: includeDeviceInfo,
            format: format
        )
        
        do {
            let output = try await exportUseCase.execute(input: input)
            Logger.info("ICloudService: Export completed successfully", log: Logger.general)
            return output
        } catch {
            Logger.error("ICloudService: Export failed: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func importReports(
        reportType: ICloudReportType,
        startDate: Date?,
        endDate: Date?,
        filterByDevice: String?
    ) async throws -> ImportICloudReportsOutput {
        Logger.info("ICloudService: Starting import with type \(reportType)", log: Logger.general)
        
        let input = ImportICloudReportsInput(
            reportType: reportType,
            startDate: startDate,
            endDate: endDate,
            filterByDevice: filterByDevice
        )
        
        do {
            let output = try await importUseCase.execute(input: input)
            Logger.info("ICloudService: Import completed successfully", log: Logger.general)
            return output
        } catch {
            Logger.error("ICloudService: Import failed: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func isICloudAvailable() async -> Bool {
        let available = await iCloudReportRepository.isICloudAvailable()
        Logger.debug("ICloudService: iCloud available: \(available)", log: Logger.general)
        return available
    }
    
    func getFileInfo() async -> (url: URL?, size: Int64?) {
        let url = await iCloudReportRepository.getICloudFileURL()
        let size = await iCloudReportRepository.getFileSize()
        
        Logger.debug("ICloudService: File info - URL: \(url?.path ?? "nil"), Size: \(size ?? 0)", log: Logger.general)
        return (url: url, size: size)
    }
    
    func deleteFile() async throws {
        Logger.info("ICloudService: Deleting iCloud file", log: Logger.general)
        
        do {
            try await iCloudReportRepository.deleteICloudFile()
            Logger.info("ICloudService: File deleted successfully", log: Logger.general)
        } catch {
            Logger.error("ICloudService: Failed to delete file: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func getFileLocationInfo() -> String {
        return iCloudReportRepository.getFileLocationInfo()
    }
    
    func requestICloudAccess() async -> Bool {
        return await iCloudReportRepository.requestICloudAccess()
    }
    
    func requestFileAccessPermissions() async -> Bool {
        return await iCloudReportRepository.requestFileAccessPermissions()
    }
} 