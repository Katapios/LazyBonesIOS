import SwiftUI

/// Вкладка 'Отчёты': список всех постов с датами и чеклистами
struct ReportsView: View {
    @EnvironmentObject var store: PostStore
    @State private var isLoadingExternal = false
    @State private var externalError: String? = nil
    @State private var isSelectionMode = false
    @State private var selectedLocalReportIDs: Set<UUID> = []
    var body: some View {
        NavigationView {
            List {
                // Локальные отчеты
                if !store.posts.isEmpty {
                    Section(header: HStack {
                        Text("Локальные отчёты").font(.title3).foregroundColor(.accentColor)
                        if isSelectionMode {
                            Spacer()
                            Button(action: selectAllLocalReports) {
                                Text(selectedLocalReportIDs.count == store.posts.count ? "Снять все" : "Выбрать все")
                                    .font(.caption)
                            }
                        }
                    }) {
                        ForEach(store.posts) { post in
                            ReportCardView(post: post, isSelectable: isSelectionMode, isSelected: selectedLocalReportIDs.contains(post.id)) {
                                toggleSelection(for: post.id)
                            }
                        }
                    }
                }
                // Внешние отчеты из Telegram
                Section(header: HStack(spacing: 8) {
                    Text("Из Telegram").font(.title3).foregroundColor(.accentColor)
                    if isLoadingExternal {
                        ProgressView().scaleEffect(0.7)
                    }
                    Button(action: {
                        isLoadingExternal = true
                        externalError = nil
                        store.fetchExternalPosts { success in
                            isLoadingExternal = false
                            if !success {
                                externalError = "Ошибка загрузки из Telegram"
                            }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }) {
                    // Предупреждение о техническом ограничении
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Техническое ограничение")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Text("Бот не может видеть свои собственные сообщения через Telegram Bot API. Поэтому отправленные вами отчёты могут не отображаться в этом списке.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        store.deleteAllBotMessages { success in
                            if success {
                                withAnimation {
                                    store.externalPosts.removeAll()
                                    store.saveExternalPosts()
                                }
                            }
                        }
                    }) {
                        Label("Очистить всю историю", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Удалить ВСЕ сообщения бота из Telegram (включая невидимые)")
                    
                    if let error = externalError {
                        Text(error).foregroundColor(.red)
                    }
                    if store.externalPosts.isEmpty && !isLoadingExternal {
                        Text("Нет внешних отчётов").foregroundColor(.gray)
                    }
                    ForEach(store.externalPosts) { post in
                        ReportCardView(post: post, isSelectable: false, isSelected: false, onSelect: nil)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Отчёты")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectionMode ? "Отмена" : "Выбрать") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedLocalReportIDs.removeAll() }
                        }
                    }
                }
                if isSelectionMode && !selectedLocalReportIDs.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive, action: deleteSelectedReports) {
                            Label("Удалить (\(selectedLocalReportIDs.count))", systemImage: "trash")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    private func toggleSelection(for id: UUID) {
        if selectedLocalReportIDs.contains(id) {
            selectedLocalReportIDs.remove(id)
        } else {
            selectedLocalReportIDs.insert(id)
        }
    }
    private func selectAllLocalReports() {
        if selectedLocalReportIDs.count == store.posts.count {
            selectedLocalReportIDs.removeAll()
        } else {
            selectedLocalReportIDs = Set(store.posts.map { $0.id })
        }
    }
    private func deleteSelectedReports() {
        withAnimation {
            store.posts.removeAll { selectedLocalReportIDs.contains($0.id) }
            selectedLocalReportIDs.removeAll()
            isSelectionMode = false
            store.save() // если есть метод сохранения
        }
    }
}

extension String {
    func simpleTelegramHTMLtoText() -> String {
        var result = self
        result = result.replacingOccurrences(of: "<li>", with: "• ")
        result = result.replacingOccurrences(of: "</li>", with: "\n")
        result = result.replacingOccurrences(of: "<ul>", with: "")
        result = result.replacingOccurrences(of: "</ul>", with: "")
        result = result.replacingOccurrences(of: "<b>", with: "")
        result = result.replacingOccurrences(of: "</b>", with: "")
        result = result.replacingOccurrences(of: "<strong>", with: "")
        result = result.replacingOccurrences(of: "</strong>", with: "")
        result = result.replacingOccurrences(of: "<i>", with: "")
        result = result.replacingOccurrences(of: "</i>", with: "")
        result = result.replacingOccurrences(of: "<em>", with: "")
        result = result.replacingOccurrences(of: "</em>", with: "")
        result = result.replacingOccurrences(of: "<br>", with: "\n")
        result = result.replacingOccurrences(of: "<br/>", with: "\n")
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        return result
    }
}

struct TelegramReportTextView: View {
    let html: String

    var safeAttributed: AttributedString? {
        guard !html.isEmpty, html.contains("<") else { return nil }
        guard let data = html.data(using: .utf8) else { return nil }
        guard html.count < 10_000 else { return nil }
        if html.contains("<script") || html.contains("<style") { return nil }
        do {
            let nsAttr = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil)
            return AttributedString(nsAttr)
        } catch {
            return nil
        }
    }

    var body: some View {
        if let attributed = safeAttributed, !attributed.characters.isEmpty {
            Text(attributed)
        } else {
            Text(html.simpleTelegramHTMLtoText()).lineLimit(nil)
        }
    }
}

struct ReportCardView: View {
    let post: Post
    var isSelectable: Bool = false
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
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
                TelegramReportTextView(html: text)
                    .font(.body)
            } else {
                if !post.goodItems.isEmpty {
                    Text("Я молодец:").font(.subheadline).bold()
                    ForEach(post.goodItems.filter { !$0.isEmpty }.uniqued(), id: \ .self) { item in
                        Text("• " + item)
                    }
                }
                if !post.badItems.isEmpty {
                    Text("Я не молодец:").font(.subheadline).bold()
                    ForEach(post.badItems.filter { !$0.isEmpty }.uniqued(), id: \ .self) { item in
                        Text("• " + item)
                    }
                }
            }
            if let urls = post.externalVoiceNoteURLs?.compactMap({ $0 }).uniqued(), !urls.isEmpty {
                ForEach(urls, id: \ .self) { url in
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
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectable { onSelect?() }
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

#Preview {
    let store: PostStore = {
        let s = PostStore()
        s.posts = [
            Post(id: UUID(), date: Date(), goodItems: ["Пункт 1", "Пункт 2"], badItems: ["Пункт 3"], published: true, voiceNotes: [VoiceNote(id: UUID(), path: "/path/to/voice.m4a")]),
            Post(id: UUID(), date: Date().addingTimeInterval(-86400), goodItems: ["Пункт 4"], badItems: [], published: false, voiceNotes: [])
        ]
        return s
    }()
    ReportsView().environmentObject(store)
} 