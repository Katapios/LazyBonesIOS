import Foundation

/// Use Case для получения всех отчетов
struct GetReportsUseCase: UseCaseWithoutInputProtocol {
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Report] {
        Logger.debug("Executing GetReportsUseCase", log: Logger.data)
        let reports: [Report] = try await repository.fetch()
        return reports
    }
}

/// Use Case для получения отчетов по дате
struct GetReportsForDateUseCase: UseCaseProtocol {
    typealias Input = Date
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: Date) async throws -> [Report] {
        Logger.debug("Executing GetReportsForDateUseCase for date: \(input)", log: Logger.data)
        let reports: [Report] = try await repository.getReportsForDate(input)
        return reports
    }
}

/// Use Case для получения отчетов по диапазону дат
struct GetReportsForDateRangeUseCase: UseCaseProtocol {
    typealias Input = (from: Date, to: Date)
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: (from: Date, to: Date)) async throws -> [Report] {
        Logger.debug("Executing GetReportsForDateRangeUseCase from: \(input.from) to: \(input.to)", log: Logger.data)
        let reports: [Report] = try await repository.getReportsForDateRange(from: input.from, to: input.to)
        return reports
    }
}

/// Use Case для поиска отчетов
struct SearchReportsUseCase: UseCaseProtocol {
    typealias Input = String
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: String) async throws -> [Report] {
        Logger.debug("Executing SearchReportsUseCase with query: \(input)", log: Logger.data)
        let reports: [Report] = try await repository.search(query: input)
        return reports
    }
}

/// Use Case для получения опубликованных отчетов
struct GetPublishedReportsUseCase: UseCaseWithoutInputProtocol {
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Report] {
        Logger.debug("Executing GetPublishedReportsUseCase", log: Logger.data)
        let reports: [Report] = try await repository.getPublishedReports()
        return reports
    }
}

/// Use Case для получения неопубликованных отчетов
struct GetUnpublishedReportsUseCase: UseCaseWithoutInputProtocol {
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Report] {
        Logger.debug("Executing GetUnpublishedReportsUseCase", log: Logger.data)
        let reports: [Report] = try await repository.getUnpublishedReports()
        return reports
    }
}

/// Use Case для получения отчетов по типу
struct GetReportsByTypeUseCase: UseCaseProtocol {
    typealias Input = ReportType
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: ReportType) async throws -> [Report] {
        Logger.debug("Executing GetReportsByTypeUseCase for type: \(input)", log: Logger.data)
        let reports: [Report] = try await repository.getReportsByType(input)
        return reports
    }
}

/// Use Case для получения внешних отчетов
struct GetExternalReportsUseCase: UseCaseWithoutInputProtocol {
    typealias Output = [Report]
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Report] {
        Logger.debug("Executing GetExternalReportsUseCase", log: Logger.data)
        let reports: [Report] = try await repository.getExternalReports()
        return reports
    }
}

/// Use Case для получения статистики отчетов
struct GetReportStatisticsUseCase: UseCaseWithoutInputProtocol {
    typealias Output = ReportStatistics
    typealias ErrorType = ReportRepositoryError
    
    private let repository: any ReportRepositoryProtocol
    
    init(repository: any ReportRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> ReportStatistics {
        Logger.debug("Executing GetReportStatisticsUseCase", log: Logger.data)
        return try await repository.getReportStatistics()
    }
} 