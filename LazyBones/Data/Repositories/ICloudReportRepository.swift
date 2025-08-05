import Foundation

/// Реализация репозитория для работы с iCloud отчетами
class ICloudReportRepository: ICloudReportRepositoryProtocol {
    
    private let fileManager: ICloudFileManager
    private let reportFormatter: any ReportFormatterProtocol
    
    init(
        fileManager: ICloudFileManager,
        reportFormatter: any ReportFormatterProtocol
    ) {
        self.fileManager = fileManager
        self.reportFormatter = reportFormatter
    }
    
    // MARK: - ICloudReportRepositoryProtocol
    
    func saveToICloud(content: String, append: Bool) async throws -> URL {
        Logger.info("ICloudReportRepository: Saving content to iCloud", log: Logger.general)
        
        do {
            let fileURL = try await fileManager.saveContent(content, append: append)
            Logger.info("ICloudReportRepository: Successfully saved to \(fileURL.path)", log: Logger.general)
            return fileURL
        } catch {
            Logger.error("ICloudReportRepository: Failed to save content: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func readFromICloud() async throws -> String {
        Logger.info("ICloudReportRepository: Reading content from iCloud", log: Logger.general)
        
        do {
            let content = try await fileManager.readContent()
            Logger.info("ICloudReportRepository: Successfully read content", log: Logger.general)
            return content
        } catch {
            Logger.error("ICloudReportRepository: Failed to read content: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func isICloudAvailable() async -> Bool {
        let available = fileManager.isICloudAvailable()
        Logger.debug("ICloudReportRepository: iCloud available: \(available)", log: Logger.general)
        return available
    }
    
    func getICloudFileURL() async -> URL? {
        let url = await fileManager.getFileURL()
        Logger.debug("ICloudReportRepository: File URL: \(url?.path ?? "nil")", log: Logger.general)
        return url
    }
    
    func deleteICloudFile() async throws {
        Logger.info("ICloudReportRepository: Deleting iCloud file", log: Logger.general)
        
        do {
            try await fileManager.deleteFile()
            Logger.info("ICloudReportRepository: Successfully deleted file", log: Logger.general)
        } catch {
            Logger.error("ICloudReportRepository: Failed to delete file: \(error)", log: Logger.general)
            throw error
        }
    }
    
    func getFileSize() async -> Int64? {
        let size = await fileManager.getFileSize()
        Logger.debug("ICloudReportRepository: File size: \(size ?? 0) bytes", log: Logger.general)
        return size
    }
    
    func getFileLocationInfo() -> String {
        return fileManager.getFileLocationInfo()
    }
    
    func requestICloudAccess() async -> Bool {
        return await fileManager.requestICloudAccess()
    }
    
    func requestFileAccessPermissions() async -> Bool {
        return await fileManager.requestFileAccessPermissions()
    }
} 