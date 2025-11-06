import WidgetKit
import SwiftUI

struct LazyBonesComplication: Widget {
    let kind: String = "LazyBonesComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("LazyBones")
        .description("Статус отчета и таймер")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let status: String
    let timeLeft: String
    let progress: Double
    let motivationalSlogan: String
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(
            date: Date(),
            status: "inProgress",
            timeLeft: "До конца: 02:15:30",
            progress: 0.65,
            motivationalSlogan: "А не пора ли сделать что-то хорошее?"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        var entries: [ComplicationEntry] = []
        let currentDate = Date()
        
        // Создаем записи на следующие 4 часа с обновлением каждые 15 минут
        for hourOffset in 0..<16 {
            guard let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate) else {
                continue
            }
            
            let entry = loadEntryForDate(entryDate)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> ComplicationEntry {
        let defaults = WatchConfig.sharedUserDefaults
        return ComplicationEntry(
            date: Date(),
            status: defaults.string(forKey: "watchStatus") ?? "notStarted",
            timeLeft: defaults.string(forKey: "watchTimeLeft") ?? "До старта: 00:00:00",
            progress: defaults.double(forKey: "watchProgress"),
            motivationalSlogan: defaults.string(forKey: "watchMotivationalSlogan") ?? ""
        )
    }
    
    private func loadEntryForDate(_ date: Date) -> ComplicationEntry {
        // Для будущих дат используем текущие данные
        // В реальном приложении можно прогнозировать изменения
        return loadCurrentEntry()
    }
}

// MARK: - Complication Views
struct ComplicationView: View {
    var entry: ComplicationEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            Text("Unsupported")
        }
    }
}

// MARK: - Circular Complication
struct CircularComplicationView: View {
    let entry: ComplicationEntry
    
    var statusColor: Color {
        switch entry.status {
        case "notStarted": return .gray
        case "inProgress": return .orange
        case "sent": return .green
        default: return .red
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(statusColor.opacity(0.3), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 2) {
                Image(systemName: statusIcon)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                Text(timeShort)
                    .font(.system(size: 8, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
    
    private var statusIcon: String {
        switch entry.status {
        case "notStarted": return "circle"
        case "inProgress": return "clock.fill"
        case "sent": return "checkmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    private var timeShort: String {
        // Извлекаем только время без префикса
        let components = entry.timeLeft.components(separatedBy: ": ")
        return components.last ?? "00:00"
    }
}

// MARK: - Rectangular Complication
struct RectangularComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("LazyBones")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                StatusIndicator(status: entry.status)
            }
            
            Text(entry.timeLeft)
                .font(.caption)
                .monospacedDigit()
            
            if !entry.motivationalSlogan.isEmpty {
                Text(entry.motivationalSlogan)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Inline Complication
struct InlineComplicationView: View {
    let entry: ComplicationEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            Text(entry.timeLeft)
                .font(.caption)
                .monospacedDigit()
        }
    }
    
    private var statusIcon: String {
        switch entry.status {
        case "notStarted": return "circle"
        case "inProgress": return "clock.fill"
        case "sent": return "checkmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Corner Complication
struct CornerComplicationView: View {
    let entry: ComplicationEntry
    
    var statusColor: Color {
        switch entry.status {
        case "notStarted": return .gray
        case "inProgress": return .orange
        case "sent": return .green
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
            Text(timeShort)
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
        }
    }
    
    private var statusIcon: String {
        switch entry.status {
        case "notStarted": return "circle"
        case "inProgress": return "clock.fill"
        case "sent": return "checkmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    private var timeShort: String {
        let components = entry.timeLeft.components(separatedBy: ": ")
        return components.last ?? "00:00"
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: String
    
    var color: Color {
        switch status {
        case "notStarted": return .gray
        case "inProgress": return .orange
        case "sent": return .green
        default: return .red
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

