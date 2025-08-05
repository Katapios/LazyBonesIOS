import SwiftUI

/// Вкладка 'Отчёты': список всех постов с датами и чеклистами
/// Версия с Clean Architecture
struct ReportsViewClean: View {
    @StateObject private var viewModel: ReportsViewModelNew
    
    init() {
        let container = DependencyContainer.shared
        
        // Получаем зависимости из DI контейнера
        let getReportsUseCase = container.resolve(GetReportsUseCase.self)!
        let deleteReportUseCase = container.resolve(DeleteReportUseCase.self)!
        let updateReportUseCase = container.resolve(UpdateReportUseCase.self)!
        let tagRepository = container.resolve(TagRepositoryProtocol.self)!
        
        self._viewModel = StateObject(wrappedValue: ReportsViewModelNew(
            getReportsUseCase: getReportsUseCase,
            deleteReportUseCase: deleteReportUseCase,
            updateReportUseCase: updateReportUseCase,
            tagRepository: tagRepository
        ))
    }

    // ВАЖНО: Оборачивайте ReportsViewClean в NavigationStack на уровне ContentView или App!
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
            .sheet(isPresented: $viewModel.state.showEvaluationSheet) { evaluationSheetContent }
            .onAppear {
                Task {
                    await viewModel.handle(.loadReports)
                }
            }
            .refreshable {
                await viewModel.handle(.refreshReports)
            }
        }
    }

    private var regularReportsSection: some View {
        Group {
            if viewModel.state.hasRegularPosts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ЛОКАЛЬНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    if viewModel.state.isSelectionMode {
                        if viewModel.state.canSelectAllRegular {
                            Button(action: {
                                Task {
                                    await viewModel.handle(.selectAllRegularReports)
                                }
                            }) {
                                Text(viewModel.state.selectAllRegularText)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.bordered)
                            .padding(.vertical, 2)
                        }
                    }
                    ForEach(viewModel.state.regularReports) { post in
                        ReportCardViewClean(
                            post: post,
                            isSelectable: viewModel.state.isSelectionMode,
                            isSelected: viewModel.state.selectedLocalReportIDs.contains(post.id),
                            onSelect: {
                                Task {
                                    await viewModel.handle(.toggleSelection(post.id))
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var customReportsSection: some View {
        Group {
            if viewModel.state.hasCustomPosts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("КАСТОМНЫЕ ОТЧЁТЫ")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    
                    customSelectionButton
                    
                    ForEach(viewModel.state.customReports) { post in
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
            if viewModel.state.isSelectionMode {
                if viewModel.state.canSelectAllCustom {
                    Button(action: {
                        Task {
                            await viewModel.handle(.selectAllCustomReports)
                        }
                    }) {
                        Text(viewModel.state.selectAllCustomText)
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
    
    private func customReportCard(for post: DomainPost) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ReportCardViewClean(
                post: post,
                isSelectable: viewModel.state.isSelectionMode,
                isSelected: viewModel.state.selectedLocalReportIDs.contains(post.id),
                onSelect: {
                    Task {
                        await viewModel.handle(.toggleSelection(post.id))
                    }
                },
                showEvaluateButton: viewModel.canEvaluateReport(post),
                isEvaluated: viewModel.isReportEvaluated(post),
                onEvaluate: {
                    Task {
                        await viewModel.handle(.startEvaluation(post))
                    }
                }
            )
            .overlay(
                Text(post.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2),
                alignment: .bottomTrailing
            )
        }
    }

    private var externalReportsSection: some View {
        ExternalReportsView(
            getReportsUseCase: DependencyContainer.shared.resolve(GetReportsUseCase.self)!,
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
                if !viewModel.state.regularReports.isEmpty || !viewModel.state.customReports.isEmpty {
                    Button(viewModel.state.isSelectionMode ? "Отмена" : "Выбрать") {
                        withAnimation {
                            viewModel.toggleSelectionMode()
                        }
                    }
                } else {
                    EmptyView()
                }
            }
            if viewModel.state.canDeleteReports {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive, action: {
                        Task {
                            await viewModel.handle(.deleteSelectedReports)
                        }
                    }) {
                        Label("Удалить (\(viewModel.state.selectedReportsCount))", systemImage: "trash")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var evaluationSheetContent: some View {
        Group {
            if let post = viewModel.state.evaluatingPost {
                CustomReportEvaluationViewClean(post: post) { checked in
                    Task {
                        await viewModel.handle(.completeEvaluation(checked))
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReportsViewClean()
        .onAppear {
            // Регистрируем сервисы для превью
            DependencyContainer.shared.registerCoreServices()
        }
} 