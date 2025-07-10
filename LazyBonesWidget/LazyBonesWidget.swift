//
//  LazyBonesWidget.swift
//  LazyBonesWidget
//
//  Created by Денис Рюмин on 10.07.2025.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct LazyBonesWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Text(Date.now, style: .date)
                .font(.headline)
            Text("Отчёт не сделан")
                .font(.title3)
                .foregroundColor(.red)
            HStack(spacing: 24) {
                VStack {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundColor(.green)
                    Text("Лайк")
                        .font(.caption)
                }
                VStack {
                    Image(systemName: "hand.thumbsdown.fill")
                        .foregroundColor(.red)
                    Text("Дизлайк")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

struct LazyBonesWidget: Widget {
    let kind: String = "LazyBonesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
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
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}
