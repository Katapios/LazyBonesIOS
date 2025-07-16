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
        SimpleEntry(date: Date(), reportStatus: Self.currentReportStatus(), deviceName: Self.deviceName(), timerString: Self.currentTimerString())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), reportStatus: Self.currentReportStatus(), deviceName: Self.deviceName(), timerString: Self.currentTimerString())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []
        let now = Date()
        // Обновлять каждую минуту на ближайший час
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            let entry = SimpleEntry(
                date: entryDate,
                reportStatus: Self.currentReportStatus(),
                deviceName: Self.deviceName(),
                timerString: Self.currentTimerString(for: entryDate)
            )
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    static func isReportDoneToday() -> Bool {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        let data = userDefaults?.data(forKey: "posts")
        print("[WIDGET] posts data:", data as Any)
        guard let data = data,
              let posts = try? JSONDecoder().decode([Post].self, from: data) else {
            return false
        }
        return posts.contains(where: { Calendar.current.isDateInToday($0.date) && $0.published })
    }
    static func deviceName() -> String {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        let name = userDefaults?.string(forKey: "deviceName")
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
        let end = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
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
        let end = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
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
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        let status = userDefaults?.string(forKey: "reportStatus") ?? "notStarted"
        return status
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reportStatus: String
    let deviceName: String
    let timerString: String
}

struct LazyBonesWidgetEntryView : View {
    var entry: SimpleEntry
    
    @AppStorage("notificationsEnabled", store: UserDefaults(suiteName: "group.com.katapios.LazyBones"))
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
                    Text("𝕷𝖆𝖇: 🅞’𝖙𝖗𝟗𝖈")
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.deviceName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(formattedDate(entry.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(statusText)
                        .font(.body)
                        .foregroundColor(statusColor)
                    if entry.reportStatus != "done" {
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
                    Text(formattedDate(entry.date))
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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
        case "done": return "Отчёт сделан"
        case "inProgress": return "Отчёт заполняется"
        default: return "Отчёт не сделан"
        }
    }
    var statusSymbol: String {
        switch entry.reportStatus {
        case "done": return "checkmark.seal.fill"
        case "inProgress": return "gearshape.fill"
        default: return "xmark.seal.fill"
        }
    }
    var statusColor: Color {
        switch entry.reportStatus {
        case "done": return .green
        case "inProgress": return .orange
        default: return .red
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
    let kind: String = "LazyBonesWidget"

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

#Preview(as: .systemSmall) {
    LazyBonesWidget()
} timeline: {
    SimpleEntry(date: .now, reportStatus: "notStarted", deviceName: "iPhone Дениса", timerString: "До старта: 00:00:00")
    SimpleEntry(date: .now, reportStatus: "inProgress", deviceName: "iPhone Дениса", timerString: "До конца: 00:00:00")
    SimpleEntry(date: .now, reportStatus: "done", deviceName: "iPhone Дениса", timerString: "Время отчёта истекло")
}

struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
}
