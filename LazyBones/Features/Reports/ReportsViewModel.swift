import Foundation
import SwiftUI

/// ViewModel для модуля Reports
class ReportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var reports: [Report] = []
    @Published var filteredReports: [Report] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedFilter: ReportFilter?
    @Published var statistics: ReportStatistics?
    
    // MARK: - Private Properties
    
    private let getReportsUseCase: GetReportsUseCase
    private let searchReportsUseCase: SearchReportsUseCase
    private let getReportStatisticsUseCase: GetReportStatisticsUseCase
    private let getReportsForDateUseCase: GetReportsForDateUseCase
    private let getReportsByTypeUseCase: GetReportsByTypeUseCase
    
    // MARK: - Initialization
    
    init(
        getReportsUseCase: GetReportsUseCase,
        searchReportsUseCase: SearchReportsUseCase,
        getReportStatisticsUseCase: GetReportStatisticsUseCase,
        getReportsForDateUseCase: GetReportsForDateUseCase,
        getReportsByTypeUseCase: GetReportsByTypeUseCase
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.searchReportsUseCase = searchReportsUseCase
        self.getReportStatisticsUseCase = getReportStatisticsUseCase
        self.getReportsForDateUseCase = getReportsForDateUseCase
        self.getReportsByTypeUseCase = getReportsByTypeUseCase
    }
    
    // MARK: - Public Methods
    
    /// Загрузить все отчеты
    @MainActor
    func loadReports() async {
        isLoading = true
        errorMessage = nil
        
        do {
            reports = try await getReportsUseCase.execute()
            applyFilters()
            Logger.info("Successfully loaded \(reports.count) reports", log: Logger.ui)
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load reports: \(error)", log: Logger.ui)
        }
        
        isLoading = false
    }
    
    /// Загрузить отчеты для конкретной даты
    @MainActor
    func loadReportsForDate(_ date: Date) async {
        isLoading = true
        errorMessage = nil
        
        do {
            reports = try await getReportsForDateUseCase.execute(input: date)
            applyFilters()
            Logger.info("Successfully loaded \(reports.count) reports for date: \(date)", log: Logger.ui)
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load reports for date: \(error)", log: Logger.ui)
        }
        
        isLoading = false
    }
    
    /// Поиск отчетов
    @MainActor
    func searchReports() async {
        guard !searchText.isEmpty else {
            await loadReports()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            reports = try await searchReportsUseCase.execute(input: searchText)
            applyFilters()
            Logger.info("Successfully found \(reports.count) reports for query: \(searchText)", log: Logger.ui)
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to search reports: \(error)", log: Logger.ui)
        }
        
        isLoading = false
    }
    
    /// Загрузить статистику
    @MainActor
    func loadStatistics() async {
        do {
            statistics = try await getReportStatisticsUseCase.execute()
            Logger.info("Successfully loaded statistics", log: Logger.ui)
        } catch {
            Logger.error("Failed to load statistics: \(error)", log: Logger.ui)
        }
    }
    
    /// Применить фильтр
    func applyFilter(_ filter: ReportFilter?) {
        selectedFilter = filter
        applyFilters()
    }
    
    /// Очистить фильтр
    func clearFilter() {
        selectedFilter = nil
        applyFilters()
    }
    
    /// Обновить отчеты
    @MainActor
    func refreshReports() async {
        await loadReports()
        await loadStatistics()
    }
    
    /// Получить отчеты по типу
    @MainActor
    func loadReportsByType(_ type: ReportType) async {
        isLoading = true
        errorMessage = nil
        
        do {
            reports = try await getReportsByTypeUseCase.execute(input: type)
            applyFilters()
            Logger.info("Successfully loaded \(reports.count) reports for type: \(type)", log: Logger.ui)
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load reports by type: \(error)", log: Logger.ui)
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func applyFilters() {
        var filtered = reports
        
        // Применяем фильтр по дате
        if let filter = selectedFilter, let dateRange = filter.dateRange {
            filtered = filtered.filter { report in
                switch dateRange {
                case .today:
                    return DateUtils.isToday(report.date)
                case .yesterday:
                    return DateUtils.isSameDay(report.date, DateUtils.yesterday(from: Date()))
                case .thisWeek:
                    let calendar = Calendar.current
                    let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                    return report.date >= weekStart
                case .thisMonth:
                    let calendar = Calendar.current
                    let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
                    return report.date >= monthStart
                case .custom(let start, let end):
                    return report.date >= start && report.date <= end
                }
            }
        }
        
        // Применяем фильтр по типу
        if let filter = selectedFilter, let type = filter.type {
            filtered = filtered.filter { $0.type == type }
        }
        
        // Применяем фильтр по статусу
        if let filter = selectedFilter, let status = filter.status {
            filtered = filtered.filter { report in
                switch status {
                case .done:
                    return report.published
                case .notStarted:
                    return !report.published
                case .inProgress:
                    // Упрощенная логика - можно улучшить
                    return false
                }
            }
        }
        
        // Применяем фильтр по внешним отчетам
        if let filter = selectedFilter, let isExternal = filter.isExternal {
            filtered = filtered.filter { $0.isExternal == isExternal }
        }
        
        filteredReports = filtered
    }
    
    // MARK: - Computed Properties
    
    /// Группированные отчеты по дате
    var groupedReports: [String: [Report]] {
        let grouped = Dictionary(grouping: filteredReports) { report in
            DateUtils.formatDate(report.date, style: .medium)
        }
        return grouped.sorted { $0.key > $1.key }.reduce(into: [:]) { result, element in
            result[element.key] = element.value
        }
    }
    
    /// Количество отчетов
    var reportsCount: Int {
        return filteredReports.count
    }
    
    /// Количество опубликованных отчетов
    var publishedReportsCount: Int {
        return filteredReports.filter { $0.published }.count
    }
    
    /// Количество неопубликованных отчетов
    var unpublishedReportsCount: Int {
        return filteredReports.filter { !$0.published }.count
    }
    
    /// Есть ли ошибка
    var hasError: Bool {
        return errorMessage != nil
    }
    
    /// Есть ли отчеты
    var hasReports: Bool {
        return !filteredReports.isEmpty
    }
} 