import Foundation

/// Черновик обычного (regular) отчёта. Хранится локально (UserDefaults) по ключу дня.
struct RegularReportDraft: Codable, Equatable {
    var date: Date
    var good: [String]
    var bad: [String]
    var voiceNotes: [VoiceNote]
    var tags: [String]
    var published: Bool
    
    init(date: Date = Date(), good: [String] = [], bad: [String] = [], voiceNotes: [VoiceNote] = [], tags: [String] = [], published: Bool = false) {
        self.date = date
        self.good = good
        self.bad = bad
        self.voiceNotes = voiceNotes
        self.tags = tags
        self.published = published
    }
}

enum RegularReportDraftStorageKey {
    /// Ключ для хранения черновика по дню (формат yyyy-MM-dd)
    static func forDay(_ date: Date) -> String {
        return "regular_report_draft_\(DateFormatter.yyyyMMdd.string(from: Calendar.current.startOfDay(for: date)))"
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
