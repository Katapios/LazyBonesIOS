import Foundation

/// Ошибки экспорта отчетов
enum ExportReportsError: LocalizedError {
    case noReportsToExport
    case iCloudNotAvailable
    case fileAccessDenied
    case formattingError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noReportsToExport:
            return "Нет отчетов для экспорта"
        case .iCloudNotAvailable:
            return "iCloud недоступен"
        case .fileAccessDenied:
            return "Нет доступа к файлу"
        case .formattingError:
            return "Ошибка форматирования"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
}

/// Use Case для экспорта отчетов в iCloud
protocol ExportReportsUseCaseProtocol: UseCaseProtocol where
    Input == ExportReportsInput,
    Output == ExportReportsOutput,
    ErrorType == ExportReportsError
{
}

/// Реализация Use Case для экспорта отчетов
class ExportReportsUseCase: ExportReportsUseCaseProtocol {
    
    private let postRepository: any PostRepositoryProtocol
    private let iCloudReportRepository: any ICloudReportRepositoryProtocol
    private let reportFormatter: any ReportFormatterProtocol
    
    init(
        postRepository: any PostRepositoryProtocol,
        iCloudReportRepository: any ICloudReportRepositoryProtocol,
        reportFormatter: any ReportFormatterProtocol
    ) {
        self.postRepository = postRepository
        self.iCloudReportRepository = iCloudReportRepository
        self.reportFormatter = reportFormatter
    }
    
    func execute(input: ExportReportsInput) async throws -> ExportReportsOutput {
        Logger.info("ExportReportsUseCase: Starting export with type \(input.reportType)", log: Logger.general)
        
        // 1. Получаем отчеты для экспорта
        let reports = try await getReportsForExport(input: input)
        
        // Проверяем, есть ли отчеты за сегодня
        let today = Calendar.current.startOfDay(for: Date())
        let todayReports = reports.filter { report in
            Calendar.current.isDate(report.date, inSameDayAs: today)
        }
        
        guard !todayReports.isEmpty else {
            Logger.warning("ExportReportsUseCase: No reports for today to export", log: Logger.general)
            throw ExportReportsError.noReportsToExport
        }
        
        // 2. Форматируем отчеты
        let formattedContent = try await reportFormatter.formatReports(
            reports: reports,
            format: input.format,
            includeDeviceInfo: input.includeDeviceInfo
        )
        
        // 3. Сохраняем в iCloud
        let fileURL = try await iCloudReportRepository.saveToICloud(
            content: formattedContent,
            append: true // Дописываем к существующему файлу
        )
        
        Logger.info("ExportReportsUseCase: Successfully exported \(reports.count) reports", log: Logger.general)
        
        return ExportReportsOutput(
            success: true,
            fileURL: fileURL,
            exportedCount: reports.count
        )
    }
    
    // MARK: - Private Methods
    
    private func getReportsForExport(input: ExportReportsInput) async throws -> [DomainPost] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch input.reportType {
        case .today:
            // Получаем отчеты только за сегодня
            return try await postRepository.fetch(for: today)
            
        case .all:
            // Получаем все отчеты
            return try await postRepository.fetch()
            
        case .custom:
            // Получаем отчеты за указанный период
            guard let startDate = input.startDate,
                  let endDate = input.endDate else {
                throw ExportReportsError.formattingError
            }
            
            let allReports = try await postRepository.fetch()
            return allReports.filter { report in
                let reportDate = calendar.startOfDay(for: report.date)
                return reportDate >= startDate && reportDate <= endDate
            }
        }
    }
} 