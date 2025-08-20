import SwiftUI

/// Вкладка 'Отчёты': список всех постов с датами и чеклистами
@available(*, deprecated, message: "Legacy PostStore-based view. Not used in runtime; kept for reference/tests during migration.")
struct ReportsView: View {
    @StateObject private var viewModel: ReportsViewModel
    
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: ReportsViewModel(store: store))
    }

    // ВАЖНО: Оборачивайте ReportsView в NavigationStack на уровне ContentView или App!
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    regularReportsSection
                    customReportsSection
                    externalReportsSection
                    iCloudReportsSection
                }
                .padding(.top, 16)
                .padding([.leading, .trailing, .bottom])
            }
            .navigationTitle("Отчёты")
            .safeAreaInset(edge: .top) { Spacer().frame(height: 8) }
            .scrollIndicators(.hidden)
            .toolbar { toolbarContent }
            .sheet(isPresented: $viewModel.showEvaluationSheet) { evaluationSheetContent }
            .onAppear {
                viewModel.loadReports()
            }
            .onChange(of: viewModel.store.posts.count) { _, _ in
                viewModel.refreshUI()
            }
        }
    }

    private var regularReportsSection: some View {
        Group {
            if viewModel.hasRegularPosts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ЛОКАЛЬНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    if viewModel.isSelectionMode {
                        if viewModel.canSelectAllRegular {
                            Button(action: viewModel.selectAllRegularReports) {
                                Text(viewModel.selectAllRegularText)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.bordered)
                            .padding(.vertical, 2)
                        }
                    }
                    ForEach(viewModel.regularPosts) { post in
                        ReportCardView(
                            post: post,
                            isSelectable: viewModel.isSelectionMode,
                            isSelected: viewModel.selectedLocalReportIDs.contains(post.id),
                            onSelect: { viewModel.toggleSelection(for: post.id) }
                        )
                    }
                }
            }
        }
    }

    private var customReportsSection: some View {
        Group {
            if viewModel.hasCustomPosts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("КАСТОМНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    
                    customSelectionButton
                    
                    ForEach(viewModel.customPosts) { post in
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
            if viewModel.isSelectionMode {
                if viewModel.canSelectAllCustom {
                    Button(action: viewModel.selectAllCustomReports) {
                        Text(viewModel.selectAllCustomText)
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
                isSelectable: viewModel.isSelectionMode,
                isSelected: viewModel.selectedLocalReportIDs.contains(post.id),
                onSelect: { viewModel.toggleSelection(for: post.id) },
                showEvaluateButton: viewModel.canEvaluateReport(post),
                isEvaluated: viewModel.isReportEvaluated(post),
                onEvaluate: {
                    viewModel.startEvaluation(for: post)
                }
            )
            .overlay(
                Text(post.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2),
                alignment: .bottomTrailing
            )
            .onChange(of: viewModel.posts.count) { _, _ in
                if let evaluatingPost = viewModel.evaluatingPost,
                   let updatedPost = viewModel.posts.first(where: { $0.id == evaluatingPost.id }) {
                    viewModel.evaluatingPost = updatedPost
                }
            }
        }
    }

    private var externalReportsSection: some View {
        ExternalReportsView(
            getExternalReportsUseCase: DependencyContainer.shared.resolve(GetExternalReportsUseCase.self)!,
            refreshExternalReportsUseCase: DependencyContainer.shared.resolve(RefreshExternalReportsUseCase.self)!,
            deleteReportUseCase: DependencyContainer.shared.resolve(DeleteReportUseCase.self)!,
            telegramIntegrationService: DependencyContainer.shared.resolve(TelegramIntegrationServiceType.self)!
        )
    }
    
    private var iCloudReportsSection: some View {
        ICloudReportsView(
            viewModel: ICloudReportsViewModel(
                iCloudService: DependencyContainer.shared.resolve(ICloudServiceProtocol.self)!
            )
        )
    }



    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.posts.isEmpty {
                    Button(viewModel.isSelectionMode ? "Отмена" : "Выбрать") {
                        withAnimation {
                            viewModel.toggleSelectionMode()
                        }
                    }
                } else {
                    EmptyView()
                }
            }
            if viewModel.canDeleteReports {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive, action: viewModel.deleteSelectedReports) {
                        Label("Удалить (\(viewModel.selectedReportsCount))", systemImage: "trash")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var evaluationSheetContent: some View {
        Group {
            if let post = viewModel.evaluatingPost {
                CustomReportEvaluationView(post: post) { checked in
                    viewModel.completeEvaluation(results: checked)
                }
            } else {
                EmptyView()
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
        _checked = State(initialValue: Array(repeating: false, count: max(1, post.goodItems.count)))
        _currentPost = State(initialValue: post)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Оцените выполнение плана")
                .font(.headline)
            
            if currentPost.goodItems.isEmpty {
                // Показываем сообщение, если нет задач для оценки
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Нет задач для оценки")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("В этом отчете нет задач, которые можно оценить.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Показываем список задач для оценки
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
                checked = Array(repeating: false, count: max(1, post.goodItems.count))
            }
        }
        .onChange(of: post.goodItems.count) { oldCount, newCount in
            // Обновляем checked при изменении количества элементов
            currentPost = post
            if checked.count != newCount {
                checked = Array(repeating: false, count: max(1, newCount))
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
    ReportsView(store: store)
} 
