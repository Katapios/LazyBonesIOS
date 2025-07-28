import Foundation

/// Протокол локального источника данных для отчетов
protocol ReportLocalDataSourceProtocol {
    func fetchReports() async throws -> [Report]
    func saveReport(_ report: Report) async throws
    func updateReport(_ report: Report) async throws
    func deleteReport(_ report: Report) async throws
    func saveReports(_ reports: [Report]) async throws
    func clearReports() async throws
    func fetchReport(withId id: UUID) async throws -> Report?
    func searchReports(query: String) async throws -> [Report]
    func fetchReportsForDate(_ date: Date) async throws -> [Report]
    func fetchReportsForDateRange(from: Date, to: Date) async throws -> [Report]
    func fetchPublishedReports() async throws -> [Report]
    func fetchUnpublishedReports() async throws -> [Report]
    func fetchReportsByType(_ type: ReportType) async throws -> [Report]
    func fetchExternalReports() async throws -> [Report]
}

/// Ошибки локального источника данных
enum ReportLocalDataSourceError: Error, LocalizedError {
    case saveFailed
    case loadFailed
    case deleteFailed
    case encodingFailed
    case decodingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save report to local storage"
        case .loadFailed:
            return "Failed to load reports from local storage"
        case .deleteFailed:
            return "Failed to delete report from local storage"
        case .encodingFailed:
            return "Failed to encode report data"
        case .decodingFailed:
            return "Failed to decode report data"
        case .fileNotFound:
            return "Report file not found"
        }
    }
}

/// Реализация локального источника данных для отчетов
class ReportLocalDataSource: ReportLocalDataSourceProtocol {
    
    private let userDefaultsManager: UserDefaultsManager
    private let fileManager: FileManager
    private let documentsDirectory: URL
    
    private let reportsKey = "savedReports"
    
    init(userDefaultsManager: UserDefaultsManager = .shared, fileManager: FileManager = .default) {
        self.userDefaultsManager = userDefaultsManager
        self.fileManager = fileManager
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - ReportLocalDataSourceProtocol
    
    func fetchReports() async throws -> [Report] {
        Logger.debug("Fetching reports from local storage", log: Logger.data)
        
        do {
            let data = try await loadReportsData()
            let reports = try JSONDecoder().decode([Report].self, from: data)
            Logger.debug("Successfully loaded \(reports.count) reports", log: Logger.data)
            return reports
        } catch {
            Logger.error("Failed to fetch reports: \(error)", log: Logger.data)
            throw ReportLocalDataSourceError.loadFailed
        }
    }
    
    func saveReport(_ report: Report) async throws {
        Logger.debug("Saving report with id: \(report.id)", log: Logger.data)
        
        var reports = try await fetchReports()
        
        // Проверяем, существует ли уже отчет с таким ID
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index] = report
        } else {
            reports.append(report)
        }
        
        try await saveReports(reports)
    }
    
    func updateReport(_ report: Report) async throws {
        Logger.debug("Updating report with id: \(report.id)", log: Logger.data)
        try await saveReport(report)
    }
    
    func deleteReport(_ report: Report) async throws {
        Logger.debug("Deleting report with id: \(report.id)", log: Logger.data)
        
        var reports = try await fetchReports()
        reports.removeAll { $0.id == report.id }
        
        try await saveReports(reports)
    }
    
    func saveReports(_ reports: [Report]) async throws {
        Logger.debug("Saving \(reports.count) reports", log: Logger.data)
        
        do {
            let data = try JSONEncoder().encode(reports)
            try await saveReportsData(data)
            Logger.debug("Successfully saved \(reports.count) reports", log: Logger.data)
        } catch {
            Logger.error("Failed to save reports: \(error)", log: Logger.data)
            throw ReportLocalDataSourceError.saveFailed
        }
    }
    
    func clearReports() async throws {
        Logger.debug("Clearing all reports", log: Logger.data)
        
        do {
            try await saveReportsData(Data())
            Logger.debug("Successfully cleared all reports", log: Logger.data)
        } catch {
            Logger.error("Failed to clear reports: \(error)", log: Logger.data)
            throw ReportLocalDataSourceError.deleteFailed
        }
    }
    
    func fetchReport(withId id: UUID) async throws -> Report? {
        Logger.debug("Fetching report with id: \(id)", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.first { $0.id == id }
    }
    
    func searchReports(query: String) async throws -> [Report] {
        Logger.debug("Searching reports with query: \(query)", log: Logger.data)
        
        let reports = try await fetchReports()
        let lowercasedQuery = query.lowercased()
        
        return reports.filter { report in
            report.goodItems.contains { $0.lowercased().contains(lowercasedQuery) } ||
            report.badItems.contains { $0.lowercased().contains(lowercasedQuery) } ||
            (report.externalText?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    func fetchReportsForDate(_ date: Date) async throws -> [Report] {
        Logger.debug("Fetching reports for date: \(date)", log: Logger.data)
        
        let reports = try await fetchReports()
        let startOfDay = DateUtils.startOfDay(for: date)
        let endOfDay = DateUtils.endOfDay(for: date)
        
        return reports.filter { report in
            report.date >= startOfDay && report.date <= endOfDay
        }
    }
    
    func fetchReportsForDateRange(from: Date, to: Date) async throws -> [Report] {
        Logger.debug("Fetching reports for date range: \(from) to \(to)", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.filter { report in
            report.date >= from && report.date <= to
        }
    }
    
    func fetchPublishedReports() async throws -> [Report] {
        Logger.debug("Fetching published reports", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.filter { $0.published }
    }
    
    func fetchUnpublishedReports() async throws -> [Report] {
        Logger.debug("Fetching unpublished reports", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.filter { !$0.published }
    }
    
    func fetchReportsByType(_ type: ReportType) async throws -> [Report] {
        Logger.debug("Fetching reports by type: \(type)", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.filter { $0.type == type }
    }
    
    func fetchExternalReports() async throws -> [Report] {
        Logger.debug("Fetching external reports", log: Logger.data)
        
        let reports = try await fetchReports()
        return reports.filter { $0.isExternal == true }
    }
    
    // MARK: - Private Methods
    
    private func loadReportsData() async throws -> Data {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        guard let data = userDefaults?.data(forKey: reportsKey) else {
            return Data()
        }
        return data
    }
    
    private func saveReportsData(_ data: Data) async throws {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        userDefaults?.set(data, forKey: reportsKey)
    }
} 