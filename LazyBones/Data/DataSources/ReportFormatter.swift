import Foundation

/// Форматтер для работы с отчетами
class ReportFormatter: ReportFormatterProtocol {
    
    private let deviceName: String
    private let deviceIdentifier: String
    
    init(deviceName: String, deviceIdentifier: String) {
        self.deviceName = deviceName
        self.deviceIdentifier = deviceIdentifier
    }
    
    // MARK: - ReportFormatterProtocol
    
    func formatReports(
        reports: [DomainPost],
        format: ReportFormat,
        includeDeviceInfo: Bool
    ) async throws -> String {
        Logger.info("ReportFormatter: Formatting \(reports.count) reports in \(format) format", log: Logger.general)
        
        switch format {
        case .telegram:
            return formatReportsAsTelegram(reports: reports, includeDeviceInfo: includeDeviceInfo)
        case .plain:
            return formatReportsAsPlain(reports: reports, includeDeviceInfo: includeDeviceInfo)
        case .json:
            return formatReportsAsJSON(reports: reports, includeDeviceInfo: includeDeviceInfo)
        }
    }
    
    func parseReports(from content: String) async throws -> [DomainICloudReport] {
        Logger.info("ReportFormatter: Parsing reports from content", log: Logger.general)
        
        let lines = content.components(separatedBy: .newlines)
        var reports: [DomainICloudReport] = []
        var currentReport: ReportBuilder?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Проверяем, является ли строка заголовком нового отчета
            if isReportHeader(line: trimmedLine) {
                // Сохраняем предыдущий отчет
                if let report = currentReport?.build() {
                    reports.append(report)
                }
                
                // Начинаем новый отчет
                currentReport = parseReportHeader(line: trimmedLine)
            } else if let report = currentReport {
                // Добавляем строку к текущему отчету
                report.addContentLine(trimmedLine)
            }
        }
        
        // Добавляем последний отчет
        if let report = currentReport?.build() {
            reports.append(report)
        }
        
        Logger.info("ReportFormatter: Parsed \(reports.count) reports", log: Logger.general)
        return reports
    }
    
    func formatSingleReport(_ report: DomainPost) -> String {
        return formatReportAsTelegram(report: report, includeDeviceInfo: true)
    }
    
    func createReportSeparator() -> String {
        return "\n" + String(repeating: "─", count: 50) + "\n"
    }
    
    // MARK: - Private Methods
    
    private func formatReportsAsTelegram(reports: [DomainPost], includeDeviceInfo: Bool) -> String {
        var result = ""
        
        for (index, report) in reports.enumerated() {
            if index > 0 {
                result += createReportSeparator()
            }
            
            result += formatReportAsTelegram(report: report, includeDeviceInfo: includeDeviceInfo)
        }
        
        return result
    }
    
    private func formatReportAsTelegram(report: DomainPost, includeDeviceInfo: Bool) -> String {
        var result = ""
        
        // Заголовок отчета
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "ru_RU")
        
        result += "📅 <b>Отчет за \(dateFormatter.string(from: report.date))</b>\n"
        
        if includeDeviceInfo {
            result += "📱 <i>Устройство: \(deviceName)</i>\n"
        }
        
        result += "\n"
        
        // Хорошие дела
        if !report.goodItems.isEmpty {
            result += "✅ <b>Хорошие дела:</b>\n"
            for item in report.goodItems {
                if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    result += "• \(item)\n"
                }
            }
            result += "\n"
        }
        
        // Плохие дела
        if !report.badItems.isEmpty {
            result += "❌ <b>Плохие дела:</b>\n"
            for item in report.badItems {
                if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    result += "• \(item)\n"
                }
            }
            result += "\n"
        }
        
        // Голосовые заметки
        if !report.voiceNotes.isEmpty {
            result += "🎤 <b>Голосовые заметки:</b> \(report.voiceNotes.count)\n\n"
        }
        
        // Для кастомных отчетов добавляем оценку
        if report.type == .custom, let isEvaluated = report.isEvaluated, isEvaluated {
            result += "⭐ <b>Отчет оценен</b>\n"
        }
        
        return result
    }
    
    private func formatReportsAsPlain(reports: [DomainPost], includeDeviceInfo: Bool) -> String {
        var result = ""
        
        for (index, report) in reports.enumerated() {
            if index > 0 {
                result += createReportSeparator()
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            dateFormatter.locale = Locale(identifier: "ru_RU")
            
            result += "Отчет за \(dateFormatter.string(from: report.date))\n"
            
            if includeDeviceInfo {
                result += "Устройство: \(deviceName)\n"
            }
            
            result += "\n"
            
            if !report.goodItems.isEmpty {
                result += "Хорошие дела:\n"
                for item in report.goodItems {
                    if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                        result += "- \(item)\n"
                    }
                }
                result += "\n"
            }
            
            if !report.badItems.isEmpty {
                result += "Плохие дела:\n"
                for item in report.badItems {
                    if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                        result += "- \(item)\n"
                    }
                }
                result += "\n"
            }
        }
        
        return result
    }
    
    private func formatReportsAsJSON(reports: [DomainPost], includeDeviceInfo: Bool) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        struct ExportReport: Codable {
            let id: String
            let date: Date
            let deviceName: String?
            let deviceIdentifier: String?
            let goodItems: [String]
            let badItems: [String]
            let type: String
            let isEvaluated: Bool?
            let evaluationResults: [Bool]?
        }
        
        let exportData = reports.map { report in
            ExportReport(
                id: report.id.uuidString,
                date: report.date,
                deviceName: includeDeviceInfo ? deviceName : nil,
                deviceIdentifier: includeDeviceInfo ? deviceIdentifier : nil,
                goodItems: report.goodItems,
                badItems: report.badItems,
                type: report.type.rawValue,
                isEvaluated: report.isEvaluated,
                evaluationResults: report.evaluationResults
            )
        }
        
        do {
            let data = try encoder.encode(exportData)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            Logger.error("ReportFormatter: Failed to encode JSON: \(error)", log: Logger.general)
            return "[]"
        }
    }
    
    private func isReportHeader(line: String) -> Bool {
        return line.contains("📅") || line.contains("Отчет за")
    }
    
    private func parseReportHeader(line: String) -> ReportBuilder {
        let builder = ReportBuilder()
        
        // Извлекаем дату из заголовка
        if let dateRange = line.range(of: #"\d{1,2}\.\d{1,2}\.\d{4}"#, options: .regularExpression) {
            let dateString = String(line[dateRange])
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            if let date = formatter.date(from: dateString) {
                builder.date = date
            }
        }
        
        // Извлекаем информацию об устройстве
        if line.contains("📱") || line.contains("Устройство:") {
            let devicePattern = #"Устройство:\s*([^\n]+)"#
            if let deviceRange = line.range(of: devicePattern, options: .regularExpression) {
                let deviceMatch = String(line[deviceRange])
                if let nameRange = deviceMatch.range(of: #":\s*([^\n]+)"#, options: .regularExpression) {
                    let deviceName = String(deviceMatch[nameRange]).trimmingCharacters(in: .whitespaces)
                    builder.deviceName = deviceName
                }
            }
        }
        
        return builder
    }
}

// MARK: - ReportBuilder

/// Вспомогательный класс для построения отчетов при парсинге
private class ReportBuilder {
    var date: Date = Date()
    var deviceName: String = ""
    var deviceIdentifier: String = ""
    var contentLines: [String] = []
    
    func addContentLine(_ line: String) {
        contentLines.append(line)
    }
    
    func build() -> DomainICloudReport {
        let content = contentLines.joined(separator: "\n")
        
        return DomainICloudReport(
            date: date,
            deviceName: deviceName.isEmpty ? "Неизвестное устройство" : deviceName,
            deviceIdentifier: deviceIdentifier.isEmpty ? UUID().uuidString : deviceIdentifier,
            reportContent: content,
            reportType: .iCloud
        )
    }
} 