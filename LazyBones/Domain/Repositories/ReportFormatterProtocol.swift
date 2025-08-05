import Foundation

/// Протокол для форматирования отчетов
protocol ReportFormatterProtocol {
    
    /// Форматировать отчеты в указанный формат
    /// - Parameters:
    ///   - reports: Список отчетов для форматирования
    ///   - format: Формат вывода
    ///   - includeDeviceInfo: Включать ли информацию об устройстве
    /// - Returns: Отформатированная строка
    func formatReports(
        reports: [DomainPost],
        format: ReportFormat,
        includeDeviceInfo: Bool
    ) async throws -> String
    
    /// Парсить отчеты из строки
    /// - Parameter content: Строка с отчетами
    /// - Returns: Список отчетов
    func parseReports(from content: String) async throws -> [DomainICloudReport]
    
    /// Форматировать один отчет в Telegram стиле
    /// - Parameter report: Отчет для форматирования
    /// - Returns: Отформатированная строка
    func formatSingleReport(_ report: DomainPost) -> String
    
    /// Создать разделитель между отчетами
    /// - Returns: Строка-разделитель
    func createReportSeparator() -> String
} 