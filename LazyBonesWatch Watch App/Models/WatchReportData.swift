import Foundation

/// Модель данных для передачи отчета между iPhone и Watch
struct WatchReportData: Codable {
    let status: String
    let timeLeft: String
    let progress: Double
    let goodItemsCount: Int
    let badItemsCount: Int
    let planItems: [String]
    let motivationalSlogan: String
}

