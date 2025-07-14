import SwiftUI

struct ReportCardView: View {
    let post: Post
    var isSelectable: Bool = false
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    
    private func getIconForItem(_ item: String, isGood: Bool) -> String {
        let lowercasedItem = item.lowercased()
        if isGood {
            if lowercasedItem.contains("не хлебил") { return "🚫" }
            if lowercasedItem.contains("не новостил") { return "📰" }
            if lowercasedItem.contains("не ел вредное") { return "🍴" }
            if lowercasedItem.contains("гулял") { return "🚶" }
            if lowercasedItem.contains("кодил") { return "💻" }
            if lowercasedItem.contains("рисовал") { return "🎨" }
            if lowercasedItem.contains("читал") { return "📚" }
            if lowercasedItem.contains("смотрел туториалы") { return "▶️" }
        } else {
            if lowercasedItem.contains("хлебил") { return "❌" }
            if lowercasedItem.contains("новостил") { return "📰" }
            if lowercasedItem.contains("ел вредное") { return "🍴" }
            if lowercasedItem.contains("не гулял") { return "🚶" }
            if lowercasedItem.contains("не кодил") { return "💻" }
            if lowercasedItem.contains("не рисовал") { return "🎨" }
            if lowercasedItem.contains("не читал") { return "📚" }
            if lowercasedItem.contains("не смотрел туториалы") { return "▶️" }
        }
        return isGood ? "✅" : "❌"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.date, style: .date)
                    .font(.headline)
                Spacer()
                if let isExternal = post.isExternal, isExternal {
                    Image(systemName: "paperplane.fill").foregroundColor(.blue)
                } else {
                    Image(systemName: "doc.text.fill").foregroundColor(.green)
                }
                if isSelectable {
                    Button(action: { onSelect?() }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .gray)
                            .imageScale(.large)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            if let author = post.authorUsername ?? post.authorFirstName, !author.isEmpty {
                Text("Автор: \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let text = post.externalText, !text.isEmpty {
                Text(text)
                    .font(.body)
            } else {
                if !post.goodItems.isEmpty {
                    Text("✅ Я молодец:").font(.subheadline).bold()
                    ForEach(Array(post.goodItems.filter { !$0.isEmpty }.uniqued().enumerated()), id: \.element) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            Text(getIconForItem(item, isGood: true))
                                .font(.system(size: 16))
                            Text(item)
                                .font(.body)
                        }
                    }
                }
                if !post.badItems.isEmpty {
                    Text("❌ Я не молодец:").font(.subheadline).bold()
                    ForEach(Array(post.badItems.filter { !$0.isEmpty }.uniqued().enumerated()), id: \.element) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            Text(getIconForItem(item, isGood: false))
                                .font(.system(size: 16))
                            Text(item)
                                .font(.body)
                        }
                    }
                }
            }
            if let urls = post.externalVoiceNoteURLs?.compactMap({ $0 }).uniqued(), !urls.isEmpty {
                ForEach(urls, id: \.self) { url in
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill").foregroundColor(.blue)
                        Text(url.lastPathComponent)
                            .font(.caption)
                    }
                }
            } else if post.voiceNotes.count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill").foregroundColor(.blue)
                    Text("Голосовая заметка")
                        .font(.caption)
                }
            }
            HStack {
                Spacer()
                Text(post.published ? "Опубликовано" : "Сохранено")
                    .font(.caption2)
                    .foregroundColor(post.published ? .green : .gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color(.secondarySystemGroupedBackground).opacity(isSelected ? 0.25 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectable { onSelect?() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Отчёт за \(post.date, formatter: dateFormatter)")
    }
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        return formatter
    }
}

#Preview {
    let post = Post(id: UUID(), date: Date(), goodItems: ["Пункт 1", "Пункт 2"], badItems: ["Пункт 3"], published: true, voiceNotes: [VoiceNote(id: UUID(), path: "/path/to/voice.m4a")])
    return ReportCardView(post: post)
        .padding()
        .background(.ultraThinMaterial)
} 