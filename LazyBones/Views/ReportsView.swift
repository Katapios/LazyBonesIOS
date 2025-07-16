import SwiftUI
    //import LazyBones.Views.Components.ReportCardView

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
                    Spacer(minLength: 8)
                    Link(destination: URL(string: "https://t.me/+Ny08CEMnQJplMGJi")!) {
                        HStack(spacing: 4) {
                            Text("В группу")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                        }
                        .padding(.leading, 2)
                        .help("Вступить в группу Telegram")
                    }
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
