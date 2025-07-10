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
        SimpleEntry(date: Date(), reportDone: false, deviceName: Self.deviceName(), timerString: Self.currentTimerString())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), reportDone: Self.isReportDoneToday(), deviceName: Self.deviceName(), timerString: Self.currentTimerString())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), reportDone: Self.isReportDoneToday(), deviceName: Self.deviceName(), timerString: Self.currentTimerString())
        let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))))
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
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            return "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now <= end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            return "До конца: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            return "Время отчёта истекло"
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reportDone: Bool
    let deviceName: String
    let timerString: String
}

struct LazyBonesWidgetEntryView : View {
    var entry: SimpleEntry

    var body: some View {
        VStack(spacing: 8) {
            Text("Лаботряс" + (entry.deviceName.isEmpty ? "" : " " + entry.deviceName))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(formattedDate(entry.date))
                .font(.subheadline)
            if entry.reportDone {
                HStack(spacing: 8) {
                    Text("Отчёт сделан")
                        .font(.title3)
                        .foregroundColor(.green)
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 8) {
                    Text("Отчёт не сделан")
                        .font(.title3)
                        .foregroundColor(.red)
                    Image(systemName: "hand.thumbsdown.fill")
                        .foregroundColor(.red)
                }
                Text(entry.timerString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    func endOfDay(from date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
    func timerString(until end: Date) -> String {
        let now = Date()
        let diff = Calendar.current.dateComponents([.hour, .minute, .second], from: now, to: end)
        let h = max(0, diff.hour ?? 0)
        let m = max(0, diff.minute ?? 0)
        let s = max(0, diff.second ?? 0)
        return String(format: "%02d:%02d:%02d", h, m, s)
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
    SimpleEntry(date: .now, reportDone: false, deviceName: "iPhone Дениса", timerString: "До старта: 00:00:00")
    SimpleEntry(date: .now, reportDone: true, deviceName: "iPhone Дениса", timerString: "Время отчёта истекло")
}

struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
}
