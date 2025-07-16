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
            ScrollView {
                VStack(spacing: 16) {
                    // --- Локальные отчёты ---
                    if !store.posts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ЛОКАЛЬНЫЕ ОТЧЁТЫ")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                            if isSelectionMode {
                                Button(action: selectAllLocalReports) {
                                    Text(selectedLocalReportIDs.count == store.posts.count ? "Снять все" : "Выбрать все")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.bordered)
                                .padding(.vertical, 2)
                            }
                            ForEach(store.posts) { post in
                                ReportCardView(
                                    post: post,
                                    isSelectable: isSelectionMode,
                                    isSelected: selectedLocalReportIDs.contains(post.id)
                                ) {
                                    toggleSelection(for: post.id)
                                }
                            }
                        }
                    }

                    // --- Внешние отчёты из Telegram ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ИЗ TELEGRAM")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                        HStack(spacing: 12) {
                            Button(action: reloadExternalReports) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Обновить")
                                }
                            }
                            .buttonStyle(.bordered)
                            Link(destination: URL(string: "https://t.me/+Ny08CEMnQJplMGJi")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                    Text("В группу")
                                }
                            }
                            .buttonStyle(.bordered)
                            if isLoadingExternal {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 2)
                        if store.externalPosts.isEmpty && !isLoadingExternal {
                            Text("Нет внешних отчётов")
                                .foregroundColor(.primary)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 16)
                        }
                        ForEach(store.externalPosts) { post in
                            ReportCardView(post: post, isSelectable: false, isSelected: false, onSelect: nil)
                        }
                    }

                    // --- Техническое предупреждение ---
                    telegramWarning
                        .foregroundColor(.primary)

                    // --- Кнопка очистки истории ---
                    telegramClearButton
                        .foregroundColor(.primary)

                    // --- Ошибка загрузки ---
                    if let error = externalError {
                        Text(error)
                            .foregroundColor(.primary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    }
                }
                .padding()
            }
            .navigationTitle("Отчёты")
            .scrollIndicators(.hidden)
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

    // MARK: - Telegram Warning Block
    private var telegramWarning: some View {
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
    }

    // MARK: - Telegram Clear Button
    private var telegramClearButton: some View {
        Button(action: clearExternalReports) {
            Label("Очистить всю историю", systemImage: "trash.fill")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 2)
        .help("Удалить ВСЕ сообщения бота из Telegram (включая невидимые)")
    }

    // MARK: - Actions
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
    private func reloadExternalReports() {
        isLoadingExternal = true
        externalError = nil
        store.fetchExternalPosts { success in
            isLoadingExternal = false
            if !success {
                externalError = "Ошибка загрузки из Telegram"
            }
        }
    }
    private func clearExternalReports() {
        store.deleteAllBotMessages { success in
            if success {
                withAnimation {
                    store.externalPosts.removeAll()
                    store.saveExternalPosts()
                }
            }
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
