import Foundation

/// Протокол удаленного источника данных для отчетов
protocol ReportRemoteDataSourceProtocol {
    func syncReports(_ reports: [Report]) async throws
    func createReport(_ report: Report) async throws
    func updateReport(_ report: Report) async throws
    func deleteReport(_ report: Report) async throws
    func clearReports() async throws
}

/// Протокол репозитория отчетов
protocol ReportRepositoryProtocol {
    associatedtype ErrorType = ReportRepositoryError
    
    // CRUD операции
    func fetch() async throws -> [Report]
    func save(_ models: [Report]) async throws
    func delete(_ model: Report) async throws
    func clear() async throws
    func create(_ model: Report) async throws
    func read(id: String) async throws -> Report?
    func update(_ model: Report) async throws
    
    // Поиск и фильтрация
    func search(query: String) async throws -> [Report]
    func filter(predicate: @escaping (Report) -> Bool) async throws -> [Report]
    
    // Специфичные для отчетов операции
    func getReportsForDate(_ date: Date) async throws -> [Report]
    func getReportsForDateRange(from: Date, to: Date) async throws -> [Report]
    func getPublishedReports() async throws -> [Report]
    func getUnpublishedReports() async throws -> [Report]
    func getReportsByType(_ type: ReportType) async throws -> [Report]
    func getExternalReports() async throws -> [Report]
    func publishReport(_ report: Report) async throws
    func unpublishReport(_ report: Report) async throws
    func getReportStatistics() async throws -> ReportStatistics
}

/// Ошибки репозитория отчетов
enum ReportRepositoryError: Error, LocalizedError {
    case reportNotFound
    case invalidReportData
    case saveFailed
    case loadFailed
    case deleteFailed
    case networkError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .reportNotFound:
            return "Report not found"
        case .invalidReportData:
            return "Invalid report data"
        case .saveFailed:
            return "Failed to save report"
        case .loadFailed:
            return "Failed to load reports"
        case .deleteFailed:
            return "Failed to delete report"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "Unknown error"
        }
    }
}

/// Реализация репозитория отчетов
class ReportRepository: ReportRepositoryProtocol {
    
    private let localDataSource: ReportLocalDataSourceProtocol
    private let remoteDataSource: ReportRemoteDataSourceProtocol?
    
    init(localDataSource: ReportLocalDataSourceProtocol, remoteDataSource: ReportRemoteDataSourceProtocol? = nil) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    // MARK: - CRUDRepositoryProtocol
    
    func fetch() async throws -> [Report] {
        Logger.debug("Fetching all reports", log: Logger.data)
        return try await localDataSource.fetchReports()
    }
    
    func save(_ models: [Report]) async throws {
        Logger.debug("Saving \(models.count) reports", log: Logger.data)
        try await localDataSource.saveReports(models)
        
        // Синхронизация с удаленным источником, если доступен
        if let remoteDataSource = remoteDataSource {
            try await remoteDataSource.syncReports(models)
        }
    }
    
    func delete(_ model: Report) async throws {
        Logger.debug("Deleting report with id: \(model.id)", log: Logger.data)
        try await localDataSource.deleteReport(model)
        
        // Удаление из удаленного источника, если доступен
        if let remoteDataSource = remoteDataSource {
            try await remoteDataSource.deleteReport(model)
        }
    }
    
    func clear() async throws {
        Logger.debug("Clearing all reports", log: Logger.data)
        try await localDataSource.clearReports()
        
        // Очистка удаленного источника, если доступен
        if let remoteDataSource = remoteDataSource {
            try await remoteDataSource.clearReports()
        }
    }
    
    func create(_ model: Report) async throws {
        Logger.debug("Creating new report with id: \(model.id)", log: Logger.data)
        try await localDataSource.saveReport(model)
        
        // Создание в удаленном источнике, если доступен
        if let remoteDataSource = remoteDataSource {
            try await remoteDataSource.createReport(model)
        }
    }
    
    func read(id: String) async throws -> Report? {
        Logger.debug("Reading report with id: \(id)", log: Logger.data)
        guard let uuid = UUID(uuidString: id) else {
            throw ReportRepositoryError.invalidReportData
        }
        return try await localDataSource.fetchReport(withId: uuid)
    }
    
    func update(_ model: Report) async throws {
        Logger.debug("Updating report with id: \(model.id)", log: Logger.data)
        try await localDataSource.updateReport(model)
        
        // Обновление в удаленном источнике, если доступен
        if let remoteDataSource = remoteDataSource {
            try await remoteDataSource.updateReport(model)
        }
    }
    
    // MARK: - SearchableRepositoryProtocol
    
    func search(query: String) async throws -> [Report] {
        Logger.debug("Searching reports with query: \(query)", log: Logger.data)
        return try await localDataSource.searchReports(query: query)
    }
    
    func filter(predicate: @escaping (Report) -> Bool) async throws -> [Report] {
        Logger.debug("Filtering reports", log: Logger.data)
        let allReports = try await fetch()
        return allReports.filter(predicate)
    }
    
    // MARK: - ReportRepositoryProtocol
    
    func getReportsForDate(_ date: Date) async throws -> [Report] {
        Logger.debug("Getting reports for date: \(date)", log: Logger.data)
        return try await localDataSource.fetchReportsForDate(date)
    }
    
    func getReportsForDateRange(from: Date, to: Date) async throws -> [Report] {
        Logger.debug("Getting reports for date range: \(from) to \(to)", log: Logger.data)
        return try await localDataSource.fetchReportsForDateRange(from: from, to: to)
    }
    
    func getPublishedReports() async throws -> [Report] {
        Logger.debug("Getting published reports", log: Logger.data)
        return try await localDataSource.fetchPublishedReports()
    }
    
    func getUnpublishedReports() async throws -> [Report] {
        Logger.debug("Getting unpublished reports", log: Logger.data)
        return try await localDataSource.fetchUnpublishedReports()
    }
    
    func getReportsByType(_ type: ReportType) async throws -> [Report] {
        Logger.debug("Getting reports by type: \(type)", log: Logger.data)
        return try await localDataSource.fetchReportsByType(type)
    }
    
    func getExternalReports() async throws -> [Report] {
        Logger.debug("Getting external reports", log: Logger.data)
        return try await localDataSource.fetchExternalReports()
    }
    
    func publishReport(_ report: Report) async throws {
        Logger.debug("Publishing report with id: \(report.id)", log: Logger.data)
        let updatedReport = report
        // Здесь должна быть логика публикации
        try await update(updatedReport)
    }
    
    func unpublishReport(_ report: Report) async throws {
        Logger.debug("Unpublishing report with id: \(report.id)", log: Logger.data)
        let updatedReport = report
        // Здесь должна быть логика отмены публикации
        try await update(updatedReport)
    }
    
    func getReportStatistics() async throws -> ReportStatistics {
        Logger.debug("Getting report statistics", log: Logger.data)
        let allReports = try await fetch()
        
        let totalReports = allReports.count
        let publishedReports = allReports.filter { $0.published }.count
        let unpublishedReports = totalReports - publishedReports
        
        let averageGoodItems = allReports.isEmpty ? 0 : Double(allReports.reduce(0) { $0 + $1.goodItems.count }) / Double(totalReports)
        let averageBadItems = allReports.isEmpty ? 0 : Double(allReports.reduce(0) { $0 + $1.badItems.count }) / Double(totalReports)
        
        // Подсчет наиболее частых элементов
        let allGoodItems = allReports.flatMap { $0.goodItems }
        let allBadItems = allReports.flatMap { $0.badItems }
        
        let mostCommonGoodItems = Array(Set(allGoodItems)).prefix(5).map { $0 }
        let mostCommonBadItems = Array(Set(allBadItems)).prefix(5).map { $0 }
        
        // Подсчет по типам
        var reportsByType: [ReportType: Int] = [:]
        for type in ReportType.allCases {
            reportsByType[type] = allReports.filter { $0.type == type }.count
        }
        
        // Подсчет по статусам (упрощенная логика)
        var reportsByStatus: [ReportStatus: Int] = [:]
        reportsByStatus[.done] = publishedReports
        reportsByStatus[.notStarted] = unpublishedReports
        reportsByStatus[.inProgress] = 0 // Нужна дополнительная логика
        
        return ReportStatistics(
            totalReports: totalReports,
            publishedReports: publishedReports,
            unpublishedReports: unpublishedReports,
            averageGoodItems: averageGoodItems,
            averageBadItems: averageBadItems,
            mostCommonGoodItems: Array(mostCommonGoodItems),
            mostCommonBadItems: Array(mostCommonBadItems),
            reportsByType: reportsByType,
            reportsByStatus: reportsByStatus
        )
    }
} 