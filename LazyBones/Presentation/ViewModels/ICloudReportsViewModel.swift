import Foundation

/// Состояние для iCloud отчетов
struct ICloudReportsState {
    var reports: [DomainICloudReport] = []
    var isLoading: Bool = false
    var error: Error? = nil
    var lastRefreshDate: Date? = nil
    var isICloudAvailable: Bool = false
    var fileInfo: (url: URL?, size: Int64?) = (nil, nil)
    
    var hasReports: Bool {
        return !reports.isEmpty
    }
    
    var reportsCount: Int {
        return reports.count
    }
    
    var formattedLastRefresh: String {
        guard let date = lastRefreshDate else { return "Никогда" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    var formattedFileSize: String {
        guard let size = fileInfo.size else { return "Неизвестно" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// События для iCloud отчетов
enum ICloudReportsEvent {
    case loadReports
    case refreshReports
    case exportReports(reportType: ICloudReportType, format: ReportFormat)
    case deleteFile
    case checkICloudAvailability
    case clearError
}

/// ViewModel для управления iCloud отчетами
@MainActor
class ICloudReportsViewModel: BaseViewModel<ICloudReportsState, ICloudReportsEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private let iCloudService: any ICloudServiceProtocol
    
    init(iCloudService: any ICloudServiceProtocol) {
        self.iCloudService = iCloudService
        super.init(initialState: ICloudReportsState())
    }
    
    override func handle(_ event: ICloudReportsEvent) async {
        switch event {
        case .loadReports:
            await loadReports()
        case .refreshReports:
            await refreshReports()
        case .exportReports(let reportType, let format):
            await exportReports(reportType: reportType, format: format)
        case .deleteFile:
            await deleteFile()
        case .checkICloudAvailability:
            await checkICloudAvailability()
        case .clearError:
            clearError()
        }
    }
    
    // MARK: - LoadableViewModel Implementation
    
    func load() async {
        await loadReports()
    }
    
    // MARK: - Private Methods
    
    private func loadReports() async {
        Logger.info("ICloudReportsViewModel: Loading reports", log: Logger.ui)
        
        state.isLoading = true
        state.error = nil
        
        do {
            // Сначала проверяем доступность iCloud
            await checkICloudAvailability()
            
            guard state.isICloudAvailable else {
                state.error = ImportICloudReportsError.iCloudNotAvailable
                state.isLoading = false
                return
            }
            
            // Загружаем отчеты за сегодня
            let output = try await iCloudService.importReports(
                reportType: .today,
                startDate: nil,
                endDate: nil,
                filterByDevice: nil
            )
            
            state.reports = output.reports
            state.lastRefreshDate = Date()
            
            // Получаем информацию о файле
            let fileInfo = await iCloudService.getFileInfo()
            state.fileInfo = fileInfo
            
            Logger.info("ICloudReportsViewModel: Loaded \(output.reports.count) reports", log: Logger.ui)
            
        } catch ImportICloudReportsError.noReportsFound {
            // Это не ошибка - просто нет отчетов
            state.reports = []
            state.lastRefreshDate = Date()
            let fileInfo = await iCloudService.getFileInfo()
            state.fileInfo = fileInfo
            Logger.info("ICloudReportsViewModel: No reports found in iCloud", log: Logger.ui)
        } catch {
            state.error = error
            Logger.error("ICloudReportsViewModel: Failed to load reports: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func refreshReports() async {
        Logger.info("ICloudReportsViewModel: Refreshing reports", log: Logger.ui)
        await loadReports()
    }
    
    private func exportReports(reportType: ICloudReportType, format: ReportFormat) async {
        Logger.info("ICloudReportsViewModel: Exporting reports", log: Logger.ui)
        
        state.isLoading = true
        state.error = nil
        
        do {
            let output = try await iCloudService.exportReports(
                reportType: reportType,
                startDate: nil,
                endDate: nil,
                includeDeviceInfo: true,
                format: format
            )
            
            if output.success {
                Logger.info("ICloudReportsViewModel: Exported \(output.exportedCount) reports", log: Logger.ui)
                // Обновляем информацию о файле после экспорта
                let fileInfo = await iCloudService.getFileInfo()
                state.fileInfo = fileInfo
            } else {
                state.error = output.error ?? ExportReportsError.unknown(NSError())
            }
            
        } catch {
            state.error = error
            Logger.error("ICloudReportsViewModel: Failed to export reports: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func deleteFile() async {
        Logger.info("ICloudReportsViewModel: Deleting file", log: Logger.ui)
        
        state.isLoading = true
        state.error = nil
        
        do {
            try await iCloudService.deleteFile()
            state.reports = []
            state.fileInfo = (nil, nil)
            state.lastRefreshDate = nil
            Logger.info("ICloudReportsViewModel: File deleted successfully", log: Logger.ui)
        } catch {
            state.error = error
            Logger.error("ICloudReportsViewModel: Failed to delete file: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func checkICloudAvailability() async {
        let available = await iCloudService.isICloudAvailable()
        state.isICloudAvailable = available
        Logger.debug("ICloudReportsViewModel: iCloud available: \(available)", log: Logger.ui)
    }
    
    private func clearError() {
        state.error = nil
    }
    
    // MARK: - File Location Info
    
    func getFileLocationInfo() -> String {
        return iCloudService.getFileLocationInfo()
    }
} 