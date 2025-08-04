import SwiftUI

/// Вкладка 'Отчёты': список всех постов с датами и чеклистами
struct ReportsView: View {
    @EnvironmentObject var store: PostStore
    @State private var isSelectionMode = false
    @State private var selectedLocalReportIDs: Set<UUID> = []
    @State private var showEvaluationSheet = false
    @State private var evaluatingPost: Post? = nil
    @AppStorage("allowCustomReportReevaluation") private var allowCustomReportReevaluation: Bool = false

    // ВАЖНО: Оборачивайте ReportsView в NavigationStack на уровне ContentView или App!
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    regularReportsSection
                    customReportsSection
                    externalReportsSection
                }
                .padding(.top, 16)
                .padding([.leading, .trailing, .bottom])
            }
            .navigationTitle("Отчёты")
            .safeAreaInset(edge: .top) { Spacer().frame(height: 8) }
            .scrollIndicators(.hidden)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEvaluationSheet) { evaluationSheetContent }
        }
    }

    private var regularReportsSection: some View {
        Group {
            if !store.posts.filter({ $0.type == .regular }).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ЛОКАЛЬНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    if isSelectionMode {
                        let regularPosts = store.posts.filter { $0.type == .regular }
                        let selectedRegular = regularPosts.filter { selectedLocalReportIDs.contains($0.id) }
                        if selectedRegular.count == 0 || selectedRegular.count == regularPosts.count {
                            Button(action: selectAllLocalReports) {
                                Text(selectedRegular.count == regularPosts.count ? "Снять все" : "Выбрать все")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.bordered)
                            .padding(.vertical, 2)
                        }
                    }
                    ForEach(store.posts.filter { $0.type == .regular }) { post in
                        ReportCardView(
                            post: post,
                            isSelectable: isSelectionMode,
                            isSelected: selectedLocalReportIDs.contains(post.id),
                            onSelect: { toggleSelection(for: post.id) }
                        )
                    }
                }
            }
        }
    }

    private var customReportsSection: some View {
        Group {
            if store.posts.contains(where: { $0.type == .custom }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("КАСТОМНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    
                    customSelectionButton
                    
                    ForEach(store.posts.filter { $0.type == .custom }) { post in
                        customReportCard(for: post)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var customSelectionButton: some View {
        Group {
            if isSelectionMode {
                let customPosts = store.posts.filter { $0.type == .custom }
                let selectedCustom = customPosts.filter { selectedLocalReportIDs.contains($0.id) }
                if selectedCustom.count == 0 || selectedCustom.count == customPosts.count {
                    Button(action: selectAllCustomReports) {
                        Text(selectedCustom.count == customPosts.count ? "Снять все" : "Выбрать все")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 2)
                } else {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func customReportCard(for post: Post) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ReportCardView(
                post: post,
                isSelectable: isSelectionMode,
                isSelected: selectedLocalReportIDs.contains(post.id),
                onSelect: { toggleSelection(for: post.id) },
                showEvaluateButton: Calendar.current.isDateInToday(post.date) && !isSelectionMode && (post.isEvaluated != true || allowCustomReportReevaluation),
                isEvaluated: post.isEvaluated == true && !allowCustomReportReevaluation,
                onEvaluate: {
                    evaluatingPost = post
                    showEvaluationSheet = true
                }
            )
            .overlay(
                Text(post.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2),
                alignment: .bottomTrailing
            )
            .onChange(of: store.posts.count) { _, _ in
                if let evaluatingPost = evaluatingPost,
                   let updatedPost = store.posts.first(where: { $0.id == evaluatingPost.id }) {
                    self.evaluatingPost = updatedPost
                }
            }
        }
    }

    private var externalReportsSection: some View {
        ExternalReportsView(
            getReportsUseCase: DependencyContainer.shared.resolve(GetReportsUseCase.self)!,
            deleteReportUseCase: DependencyContainer.shared.resolve(DeleteReportUseCase.self)!,
            telegramIntegrationService: DependencyContainer.shared.resolve(TelegramIntegrationServiceType.self)!
        )
    }



    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !store.posts.isEmpty {
                    Button(isSelectionMode ? "Отмена" : "Выбрать") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedLocalReportIDs.removeAll() }
                        }
                    }
                } else {
                    EmptyView()
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

    private var evaluationSheetContent: some View {
        Group {
            if let post = evaluatingPost {
                CustomReportEvaluationView(post: post) { checked in
                    if let idx = store.posts.firstIndex(where: { $0.id == post.id }) {
                        var updated = store.posts[idx]
                        updated.evaluationResults = checked
                        updated.isEvaluated = true
                        store.posts[idx] = updated
                        evaluatingPost = updated
                        store.save()
                    }
                }
            } else {
                EmptyView()
            }
        }
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
        if selectedLocalReportIDs.count == store.posts.filter({ $0.type == .regular }).count {
            selectedLocalReportIDs.removeAll()
        } else {
            selectedLocalReportIDs = Set(store.posts.filter({ $0.type == .regular }).map { $0.id })
        }
    }
    private func selectAllCustomReports() {
        let customPosts = store.posts.filter { $0.type == .custom }
        if selectedLocalReportIDs.count == customPosts.count {
            selectedLocalReportIDs.removeAll()
        } else {
            selectedLocalReportIDs = Set(customPosts.map { $0.id })
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

struct CustomReportEvaluationView: View {
    let post: Post
    let onComplete: (_ checked: [Bool]) -> Void
    @State private var checked: [Bool]
    @State private var currentPost: Post
    @Environment(\.dismiss) var dismiss
    
    init(post: Post, onComplete: @escaping ([Bool]) -> Void) {
        self.post = post
        self.onComplete = onComplete
        // Инициализируем checked с правильным размером
        _checked = State(initialValue: Array(repeating: false, count: post.goodItems.count))
        _currentPost = State(initialValue: post)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Оцените выполнение плана")
                .font(.headline)
            List {
                ForEach(currentPost.goodItems.indices, id: \.self) { idx in
                    HStack {
                        Text(currentPost.goodItems[idx])
                        Spacer()
                        Toggle("", isOn: $checked[idx])
                            .labelsHidden()
                    }
                }
            }
            Button("Завершить отчет") {
                onComplete(checked)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .onAppear {
            // Обновляем currentPost и checked при появлении view
            currentPost = post
            if checked.count != post.goodItems.count {
                checked = Array(repeating: false, count: post.goodItems.count)
            }
        }
        .onChange(of: post.goodItems.count) { oldCount, newCount in
            // Обновляем checked при изменении количества элементов
            currentPost = post
            if checked.count != newCount {
                checked = Array(repeating: false, count: newCount)
            }
        }
    }
}

#Preview {
    let store: PostStore = {
        let s = PostStore()
        s.posts = [
            Post(id: UUID(), date: Date(), goodItems: ["Пункт 1", "Пункт 2"], badItems: ["Пункт 3"], published: true, voiceNotes: [VoiceNote(id: UUID(), path: "/path/to/voice.m4a")], type: .regular),
            Post(id: UUID(), date: Date().addingTimeInterval(-86400), goodItems: ["Пункт 4"], badItems: [], published: false, voiceNotes: [], type: .regular),
            Post(id: UUID(), date: Date().addingTimeInterval(-3600), goodItems: ["Пункт 5"], badItems: [], published: true, voiceNotes: [], type: .custom),
            Post(id: UUID(), date: Date().addingTimeInterval(-7200), goodItems: ["Пункт 7"], badItems: ["Пункт 8"], published: false, voiceNotes: [], type: .custom)
        ]
        return s
    }()
    ReportsView().environmentObject(store)
} 
