import Foundation

/// Ошибки импорта отчетов
enum ImportICloudReportsError: LocalizedError {
    case iCloudNotAvailable
    case fileNotFound
    case fileAccessDenied
    case parsingError
    case noReportsFound
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud недоступен"
        case .fileNotFound:
            return "Файл отчетов не найден"
        case .fileAccessDenied:
            return "Нет доступа к файлу"
        case .parsingError:
            return "Ошибка чтения файла"
        case .noReportsFound:
            return "Отчеты не найдены"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
}

/// Use Case для импорта отчетов из iCloud
protocol ImportICloudReportsUseCaseProtocol: UseCaseProtocol where
    Input == ImportICloudReportsInput,
    Output == ImportICloudReportsOutput,
    ErrorType == ImportICloudReportsError
{
}

/// Реализация Use Case для импорта отчетов
class ImportICloudReportsUseCase: ImportICloudReportsUseCaseProtocol {
    
    private let iCloudReportRepository: any ICloudReportRepositoryProtocol
    private let reportFormatter: any ReportFormatterProtocol
    
    init(
        iCloudReportRepository: any ICloudReportRepositoryProtocol,
        reportFormatter: any ReportFormatterProtocol
    ) {
        self.iCloudReportRepository = iCloudReportRepository
        self.reportFormatter = reportFormatter
    }
    
    func execute(input: ImportICloudReportsInput) async throws -> ImportICloudReportsOutput {
        Logger.info("ImportICloudReportsUseCase: Starting import with type \(input.reportType)", log: Logger.general)
        
        // 1. Читаем файл из iCloud
        let fileContent = try await iCloudReportRepository.readFromICloud()
        
        guard !fileContent.isEmpty else {
            Logger.warning("ImportICloudReportsUseCase: File is empty", log: Logger.general)
            throw ImportICloudReportsError.noReportsFound
        }
        
        // 2. Парсим отчеты из файла
        let allReports = try await reportFormatter.parseReports(from: fileContent)
        
        // 3. Фильтруем отчеты согласно входным параметрам
        let filteredReports = filterReports(allReports, input: input)
        
        guard !filteredReports.isEmpty else {
            Logger.warning("ImportICloudReportsUseCase: No reports found after filtering", log: Logger.general)
            throw ImportICloudReportsError.noReportsFound
        }
        
        Logger.info("ImportICloudReportsUseCase: Successfully imported \(filteredReports.count) reports", log: Logger.general)
        
        return ImportICloudReportsOutput(
            success: true,
            reports: filteredReports,
            importedCount: filteredReports.count
        )
    }
    
    // MARK: - Private Methods
    
    private func filterReports(_ reports: [DomainICloudReport], input: ImportICloudReportsInput) -> [DomainICloudReport] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var filteredReports = reports
        
        // Фильтруем по типу отчета
        switch input.reportType {
        case .today:
            // Только за сегодня
            filteredReports = filteredReports.filter { report in
                calendar.isDate(report.date, inSameDayAs: today)
            }
            
        case .all:
            // Все отчеты (без фильтрации по дате)
            break
            
        case .custom:
            // За указанный период
            if let startDate = input.startDate,
               let endDate = input.endDate {
                filteredReports = filteredReports.filter { report in
                    let reportDate = calendar.startOfDay(for: report.date)
                    return reportDate >= startDate && reportDate <= endDate
                }
            }
        }
        
        // Фильтруем по устройству (если указано)
        if let deviceFilter = input.filterByDevice {
            filteredReports = filteredReports.filter { report in
                report.deviceName.contains(deviceFilter) || 
                report.deviceIdentifier.contains(deviceFilter)
            }
        }
        
        // Сортируем по дате (новые сначала)
        return filteredReports.sorted { $0.date > $1.date }
    }
} 