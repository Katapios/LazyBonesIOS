//
//  LazyBonesWidget.swift
//  LazyBonesWidget
//
//  Created by Денис Рюмин on 10.07.2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let now = Date()
        return SimpleEntry(
            date: now,
            reportStatus: Self.currentReportStatus(),
            deviceName: Self.deviceName(),
            timerString: Self.currentTimerString(),
            motivationalSlogan: Self.generateMotivationalSlogan(for: now)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let now = Date()
        let entry = SimpleEntry(
            date: now,
            reportStatus: Self.currentReportStatus(),
            deviceName: Self.deviceName(),
            timerString: Self.currentTimerString(),
            motivationalSlogan: Self.generateMotivationalSlogan(for: now)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []
        let now = Date()
        let calendar = Calendar.current
        
        // Генерируем лозунги каждые 15 минут на ближайшие 4 часа (16 записей)
        for quarterHourOffset in 0..<16 {
            let entryDate = calendar.date(byAdding: .minute, value: quarterHourOffset * 15, to: now)!
            // Генерируем новый лозунг для каждого 15-минутного интервала
            let slogan = Self.generateMotivationalSlogan(for: entryDate)
            let entry = SimpleEntry(
                date: entryDate,
                reportStatus: Self.currentReportStatus(),
                deviceName: Self.deviceName(),
                timerString: Self.currentTimerString(for: entryDate),
                motivationalSlogan: slogan
            )
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    static func isReportDoneToday() -> Bool {
        let userDefaults = WidgetConfig.sharedUserDefaults
        let data = userDefaults.data(forKey: "posts")
        print("[WIDGET] posts data:", data as Any)
        guard let data = data,
              let posts = try? JSONDecoder().decode([Post].self, from: data) else {
            return false
        }
        return posts.contains(where: { Calendar.current.isDateInToday($0.date) && $0.published })
    }
    static func deviceName() -> String {
        let userDefaults = WidgetConfig.sharedUserDefaults
        let name = userDefaults.string(forKey: "deviceName")
        print("[WIDGET] deviceName из UserDefaults:", name as Any)
        if let saved = name, !saved.isEmpty {
            return saved
        }
        // Получаем реальное имя устройства (в WidgetKit нельзя использовать UIDevice, используем hostName)
        var realName = ProcessInfo.processInfo.hostName
        if realName.hasSuffix(".local") {
            realName = String(realName.dropLast(6))
        }
        print("[WIDGET] deviceName по умолчанию (hostName):", realName)
        return realName
    }
    static func currentTimerString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        if now < start {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: start)
            return "До старта: " + String(format: "%02d:%02d", diff.hour ?? 0, diff.minute ?? 0)
        } else if now >= start && now <= end {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: end)
            return "До конца: " + String(format: "%02d:%02d", diff.hour ?? 0, diff.minute ?? 0)
        } else {
            return "Время отчёта истекло"
        }
    }
    static func currentTimerString(for date: Date) -> String {
        let calendar = Calendar.current
        let now = date
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        if now < start {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: start)
            return "До старта: " + String(format: "%02d:%02d", diff.hour ?? 0, diff.minute ?? 0)
        } else if now >= start && now <= end {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: end)
            return "До конца: " + String(format: "%02d:%02d", diff.hour ?? 0, diff.minute ?? 0)
        } else {
            return "Время отчёта истекло"
        }
    }
    static func currentReportStatus() -> String {
        let userDefaults = WidgetConfig.sharedUserDefaults
        let status = userDefaults.string(forKey: "reportStatus") ?? "notStarted"
        return status
    }
    
    static func getTodayPlanItems(for date: Date = Date()) -> [String] {
        let userDefaults = WidgetConfig.sharedUserDefaults
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        var planItems: [String] = []
        
        // 1. Ищем в сохраненных custom отчетах за сегодня
        if let data = userDefaults.data(forKey: "posts"),
           let posts = try? JSONDecoder().decode([Post].self, from: data) {
            if let customReport = posts.first(where: { post in
                post.type == .custom &&
                calendar.isDate(post.date, inSameDayAs: today) &&
                !post.goodItems.isEmpty
            }) {
                planItems.append(contentsOf: customReport.goodItems)
            }
        }
        
        // 2. Ищем в черновиках планов
        // PlanningLocalDataSource теперь использует app group UserDefaults (AppConfig.sharedUserDefaults)
        // Пробуем разные варианты формата даты для совместимости с разными локалями
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                return formatter
            }()
        ]
        
        let standardDefaults = UserDefaults.standard
        
        // Пробуем все варианты форматов даты в обоих UserDefaults
        for formatter in dateFormatters {
            let dateKey = formatter.string(from: today)
            let planKey = "plan_" + dateKey
            
            // Сначала пробуем в app group UserDefaults (основное место хранения)
            if let planData = userDefaults.data(forKey: planKey),
               let planItemsFromDraft = try? JSONDecoder().decode([String].self, from: planData) {
                planItems.append(contentsOf: planItemsFromDraft)
                break // Нашли план, не нужно пробовать другие форматы
            }
            
            // Также пробуем в стандартном UserDefaults для обратной совместимости
            if let planData = standardDefaults.data(forKey: planKey),
               let planItemsFromDraft = try? JSONDecoder().decode([String].self, from: planData) {
                planItems.append(contentsOf: planItemsFromDraft)
                break // Нашли план, не нужно пробовать другие форматы
            }
        }
        
        // Также пробуем старый формат ключа из DailyReportView (для обратной совместимости)
        for formatter in dateFormatters {
            let dateKey = formatter.string(from: today)
            let oldPlanKey = "third_screen_plan_" + dateKey
            
            if let planData = standardDefaults.data(forKey: oldPlanKey),
               let planDataStruct = try? JSONDecoder().decode(ThirdScreenPlanData.self, from: planData) {
                planItems.append(contentsOf: planDataStruct.goodItems)
                break
            }
        }
        
        // Фильтруем пустые пункты и удаляем дубликаты
        let nonEmptyItems = planItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var seen = Set<String>()
        let uniqueItems = nonEmptyItems.filter { item in
            guard !seen.contains(item) else { return false }
            seen.insert(item)
            return true
        }
        return uniqueItems
    }
    
    static func generateMotivationalSlogan(for date: Date = Date()) -> String {
        let planItems = getTodayPlanItems(for: date)
        
        // Если есть пункты плана - генерируем мотивационную фразу
        if !planItems.isEmpty {
            // Используем дату как seed для псевдослучайного выбора, чтобы лозунг менялся каждые 15 минут
            let quarterHourInterval = max(0, Int(date.timeIntervalSince1970) / (15 * 60)) // Интервал 15 минут
            let itemIndex = quarterHourInterval % planItems.count
            let selectedItem = planItems[itemIndex]
            
            let motivationalPhrases = [
                "А не пора ли сделать",
                "Пора бы уже",
                "Время для",
                "Не забудь про",
                "Сегодня нужно",
                "Пора заняться"
            ]
            // Используем комбинацию интервала и количества пунктов для выбора фразы
            let phraseIndex = (quarterHourInterval + planItems.count) % motivationalPhrases.count
            let selectedPhrase = motivationalPhrases[phraseIndex]
            
            return "\(selectedPhrase) \(selectedItem)"
        }
        
        // Если пунктов нет - возвращаем дату
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reportStatus: String
    let deviceName: String
    let timerString: String
    let motivationalSlogan: String
}

struct LazyBonesWidgetEntryView : View {
    var entry: SimpleEntry
    
    @AppStorage("notificationsEnabled", store: WidgetConfig.sharedUserDefaults)
    var notificationsEnabled: Bool = false
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            HStack {
                Spacer()
                Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .foregroundColor(notificationsEnabled ? .accentColor : .gray)
                    .padding(8)
            }
        }
    }

    @ViewBuilder
    var content: some View {
        switch family {
        case .systemSmall:
            VStack(spacing: 8) {
                Spacer(minLength: 4)
                Text("𝕷𝖆𝖇: 🅞’𝖙𝖗𝟗𝖈")
                    .font(.caption)
                    .minimumScaleFactor(1.5)
                    .multilineTextAlignment(.center)
                Text(entry.deviceName)
                Image(systemName: statusSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(statusColor)
                if entry.reportStatus != "done" {
                    VStack(spacing: 0) {
                        Text(timerPrefix)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text(timerValue)
                            .font(.caption2).bold()
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        case .systemMedium:
            HStack(spacing: 12) {
                Image(systemName: statusSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.trailing, 15)
                    .foregroundColor(statusColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("𝕷𝖆𝖇: 🅞'𝖙𝖗𝟗𝖈")
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.deviceName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.motivationalSlogan)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text(statusText)
                        .font(.body)
                        .foregroundColor(statusColor)
                    if entry.reportStatus != "done" && entry.reportStatus != "sent" {
                        Text(entry.timerString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
        case .systemLarge:
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                VStack(alignment: .center, spacing: 20) {
                    Text("𝕷𝖆𝖇: 🅞’𝖙𝖗𝟗𝖈")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(entry.deviceName)
                        .font(.title2)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    Image(systemName: statusSymbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(statusColor)
                        .padding(.vertical, 8)
                    Text(statusText)
                        .font(.title.bold())
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                    Text(entry.motivationalSlogan)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    if entry.reportStatus != "done" {
                        VStack(spacing: 2) {
                            Text(timerPrefix)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text(timerValue)
                                .font(.largeTitle.bold())
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        default:
            VStack {
                Image(systemName: statusSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.body)
                    .foregroundColor(statusColor)
            }
            .padding()
        }
    }

    var statusText: String {
        switch entry.reportStatus {
        case "done": return "Отчёт завершен"
        case "sent": return "Отчёт отправлен"
        case "inProgress": return "Отчёт заполняется..."
        case "notSent": return "Отчёт не отправлен"
        case "notCreated": return "Отчёт не создан"
        case "notStarted": return "Заполни отчет"
        default: return "Статус неизвестен"
        }
    }
    
    var statusSymbol: String {
        switch entry.reportStatus {
        case "done": return "checkmark.seal.fill"
        case "sent": return "paperplane.fill"
        case "inProgress": return "pencil.circle.fill"
        case "notSent": return "tray.fill"
        case "notCreated": return "doc.fill"
        case "notStarted": return "exclamationmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch entry.reportStatus {
        case "done", "sent": return .green
        case "inProgress": return .orange
        case "notSent": return .yellow
        case "notCreated", "notStarted": return .red
        default: return .gray
        }
    }
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    var timerPrefix: String {
        if entry.timerString.hasPrefix("До конца") { return "До конца:" }
        if entry.timerString.hasPrefix("До старта") { return "До старта:" }
        return ""
    }
    var timerValue: String {
        if let range = entry.timerString.range(of: ": ") {
            return String(entry.timerString[range.upperBound...])
        }
        return entry.timerString
    }
}

struct LazyBonesWidget: Widget {
    let kind: String = WidgetConfig.primaryWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LazyBonesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemMedium) {
    LazyBonesWidget()
} timeline: {
    SimpleEntry(date: Date(), reportStatus: "notStarted", deviceName: "iPhone Дениса", timerString: "До старта: 00:00:00", motivationalSlogan: "А не пора ли сделать зарядку")
    SimpleEntry(date: Date(), reportStatus: "inProgress", deviceName: "iPhone Дениса", timerString: "До конца: 00:00:00", motivationalSlogan: "Пора бы уже прочитать книгу")
    SimpleEntry(date: Date(), reportStatus: "done", deviceName: "iPhone Дениса", timerString: "", motivationalSlogan: "понедельник, 1 января 2024 г.")
    SimpleEntry(date: Date(), reportStatus: "sent", deviceName: "iPhone Дениса", timerString: "", motivationalSlogan: "Сегодня нужно позвонить маме")
    SimpleEntry(date: Date(), reportStatus: "notSent", deviceName: "iPhone Дениса", timerString: "До конца: 00:00:00", motivationalSlogan: "понедельник, 1 января 2024 г.")
    SimpleEntry(date: Date(), reportStatus: "notCreated", deviceName: "iPhone Дениса", timerString: "До старта: 00:00:00", motivationalSlogan: "понедельник, 1 января 2024 г.")
}

struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
    var type: PostType = .regular
}

enum PostType: String, Codable, CaseIterable {
    case regular // обычный отчет
    case custom // кастомный отчет (план/теги)
    case external // внешний отчет из Telegram
    case iCloud // отчет из iCloud
}

// Вспомогательная структура для старого формата планов
private struct ThirdScreenPlanData: Codable {
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [String]?
}
