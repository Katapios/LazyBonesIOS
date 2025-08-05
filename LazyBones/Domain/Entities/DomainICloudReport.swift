import Foundation

/// Domain Entity - iCloud отчет (совместный отчет из iCloud)
struct DomainICloudReport: Codable, Identifiable {
    let id: UUID
    let date: Date
    let deviceName: String
    let deviceIdentifier: String
    let username: String?
    let reportContent: String
    let reportType: PostType
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        deviceName: String,
        deviceIdentifier: String,
        username: String? = nil,
        reportContent: String,
        reportType: PostType = .regular,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.deviceName = deviceName
        self.deviceIdentifier = deviceIdentifier
        self.username = username
        self.reportContent = reportContent
        self.reportType = reportType
        self.timestamp = timestamp
    }
}

/// Тип экспорта/импорта iCloud отчетов
enum ICloudReportType: String, Codable, CaseIterable {
    case today = "today"           // Только за сегодня
    case all = "all"               // Все отчеты
    case custom = "custom"         // За определенный период
}

/// Настройки для экспорта отчетов
struct ExportReportsInput {
    let reportType: ICloudReportType
    let startDate: Date?
    let endDate: Date?
    let includeDeviceInfo: Bool
    let format: ReportFormat
    
    init(
        reportType: ICloudReportType = .today,
        startDate: Date? = nil,
        endDate: Date? = nil,
        includeDeviceInfo: Bool = true,
        format: ReportFormat = .telegram
    ) {
        self.reportType = reportType
        self.startDate = startDate
        self.endDate = endDate
        self.includeDeviceInfo = includeDeviceInfo
        self.format = format
    }
}

/// Формат экспорта отчетов
enum ReportFormat: String, Codable, CaseIterable {
    case telegram = "telegram"     // Как в Telegram
    case plain = "plain"           // Простой текст
    case json = "json"             // JSON формат
}

/// Результат экспорта
struct ExportReportsOutput {
    let success: Bool
    let fileURL: URL?
    let exportedCount: Int
    let error: Error?
    
    init(
        success: Bool,
        fileURL: URL? = nil,
        exportedCount: Int = 0,
        error: Error? = nil
    ) {
        self.success = success
        self.fileURL = fileURL
        self.exportedCount = exportedCount
        self.error = error
    }
}

/// Настройки для импорта отчетов
struct ImportICloudReportsInput {
    let reportType: ICloudReportType
    let startDate: Date?
    let endDate: Date?
    let filterByDevice: String?
    
    init(
        reportType: ICloudReportType = .today,
        startDate: Date? = nil,
        endDate: Date? = nil,
        filterByDevice: String? = nil
    ) {
        self.reportType = reportType
        self.startDate = startDate
        self.endDate = endDate
        self.filterByDevice = filterByDevice
    }
}

/// Результат импорта
struct ImportICloudReportsOutput {
    let success: Bool
    let reports: [DomainICloudReport]
    let importedCount: Int
    let error: Error?
    
    init(
        success: Bool,
        reports: [DomainICloudReport] = [],
        importedCount: Int = 0,
        error: Error? = nil
    ) {
        self.success = success
        self.reports = reports
        self.importedCount = importedCount
        self.error = error
    }
} 