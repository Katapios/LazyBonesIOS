import SwiftUI

/// View для отображения внешних отчетов из Telegram
struct ExternalReportsView: View {
    @StateObject private var viewModel: ExternalReportsViewModel
    @Environment(\.openURL) private var openURL
    
    init(
        getExternalReportsUseCase: any GetExternalReportsUseCaseProtocol,
        refreshExternalReportsUseCase: any RefreshExternalReportsUseCaseProtocol,
        deleteReportUseCase: any DeleteReportUseCaseProtocol,
        telegramIntegrationService: any TelegramIntegrationServiceProtocol
    ) {
        self._viewModel = StateObject(wrappedValue: ExternalReportsViewModel(
            getExternalReportsUseCase: getExternalReportsUseCase,
            refreshExternalReportsUseCase: refreshExternalReportsUseCase,
            deleteReportUseCase: deleteReportUseCase,
            telegramIntegrationService: telegramIntegrationService
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection
            controlsSection
            contentSection
            warningSection
            clearButtonSection
        }
        .onAppear {
            Task {
                await viewModel.handle(.loadReports)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        Text("ИЗ TELEGRAM")
            .font(.title3)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { 
                    Task {
                        await viewModel.handle(.refreshFromTelegram)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Обновить")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.state.isRefreshing)
                
                Button(action: { 
                    Task {
                        await viewModel.handle(.openTelegramGroup)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                        Text("В группу")
                    }
                }
                .buttonStyle(.bordered)
                .onTapGesture {
                    if let url = URL(string: "https://t.me/+Ny08CEMnQJplMGJi") {
                        openURL(url)
                    }
                }
                
                if viewModel.state.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            // Кнопка для отладки - сброс lastUpdateId
            #if DEBUG
            Button(action: { 
                Task {
                    await viewModel.handle(.resetLastUpdateId)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Сбросить ID (Debug)")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.orange)
            .font(.caption)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            if viewModel.state.showEmptyState {
                emptyStateView
            } else {
                reportsListView
            }
        }
    }
    
    private var emptyStateView: some View {
        Text("Нет внешних отчётов")
            .foregroundColor(.primary)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
    
    private var reportsListView: some View {
        VStack(spacing: 8) {
            if viewModel.state.isSelectionMode {
                selectionControlsView
            }
            
            ForEach(viewModel.state.reports, id: \.id) { post in
                ReportCardView(
                    post: PostMapper.toDataModel(post),
                    isSelectable: viewModel.state.isSelectionMode,
                    isSelected: viewModel.state.selectedReportIDs.contains(post.id),
                    onSelect: { 
                        Task {
                            await viewModel.handle(.selectReport(post.id))
                        }
                    }
                )
            }
        }
    }
    
    private var selectionControlsView: some View {
        HStack {
            if viewModel.state.selectedReportIDs.isEmpty || viewModel.state.selectedReportIDs.count == viewModel.state.reports.count {
                Button(action: { 
                    Task {
                        await viewModel.handle(.selectAllReports)
                    }
                }) {
                    Text(viewModel.state.selectedReportIDs.count == viewModel.state.reports.count ? "Снять все" : "Выбрать все")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Warning Section
    private var warningSection: some View {
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
    
    // MARK: - Clear Button Section
    private var clearButtonSection: some View {
        Button(action: { 
            Task {
                await viewModel.handle(.clearHistory)
            }
        }) {
            Label("Очистить всю историю", systemImage: "trash.fill")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 2)
        .disabled(!viewModel.state.canClearHistory)
        .help("Удалить ВСЕ сообщения бота из Telegram (включая невидимые)")
    }
}

#Preview {
    // Локальные простые моки для превью
    final class PreviewGetExternalReports: GetExternalReportsUseCaseProtocol {
        func execute(input: GetExternalReportsInput) async throws -> [DomainPost] {
            return [
                DomainPost(
                    id: UUID(),
                    date: Date(),
                    goodItems: ["Выполнил задачу 1", "Выполнил задачу 2"],
                    badItems: ["Не выполнил задачу 3"],
                    published: true,
                    voiceNotes: [],
                    type: .regular
                ),
                DomainPost(
                    id: UUID(),
                    date: Date().addingTimeInterval(-86400),
                    goodItems: ["Выполнил задачу 4"],
                    badItems: [],
                    published: true,
                    voiceNotes: [],
                    type: .regular
                )
            ]
        }
    }
    
    final class PreviewRefreshExternalReports: RefreshExternalReportsUseCaseProtocol {
        func execute() async throws { /* no-op for preview */ }
    }
    
    final class PreviewDeleteReport: DeleteReportUseCaseProtocol {
        func execute(input: DeleteReportInput) async throws { /* no-op for preview */ }
    }
    
    final class PreviewTelegramService: TelegramIntegrationServiceProtocol {
        // Properties required by protocol
        var externalPosts: [Post] = []
        var telegramToken: String? = "test_token"
        var telegramChatId: String? = "preview_chat"
        var telegramBotId: String? = "preview_bot"
        var lastUpdateId: Int? = nil

        // Settings Management
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
            telegramToken = token
            telegramChatId = chatId
            telegramBotId = botId
        }
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
            (telegramToken, telegramChatId, telegramBotId)
        }
        func saveLastUpdateId(_ updateId: Int) { lastUpdateId = updateId }
        func resetLastUpdateId() { lastUpdateId = nil }
        func refreshTelegramService() {}

        // External Posts Management
        func fetchExternalPosts(completion: @escaping (Bool) -> Void) { completion(true) }
        func saveExternalPosts() {}
        func loadExternalPosts() {}
        func deleteBotMessages(completion: @escaping (Bool) -> Void) { completion(true) }
        func deleteAllBotMessages(completion: @escaping (Bool) -> Void) { completion(true) }

        // Message Conversion
        func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? { nil }

        // Combined Posts
        func getAllPosts() -> [Post] { externalPosts }

        // Report Formatting
        func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String { "Preview formatted" }
    }
    
    return ExternalReportsView(
        getExternalReportsUseCase: PreviewGetExternalReports(),
        refreshExternalReportsUseCase: PreviewRefreshExternalReports(),
        deleteReportUseCase: PreviewDeleteReport(),
        telegramIntegrationService: PreviewTelegramService()
    )
}
 