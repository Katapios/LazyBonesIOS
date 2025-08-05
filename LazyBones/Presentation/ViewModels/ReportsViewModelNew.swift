import Foundation

/// Новый ReportsViewModel с Clean Architecture
@MainActor
class ReportsViewModelNew: BaseViewModel<ReportsState, ReportsEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // MARK: - Dependencies
    private let getReportsUseCase: GetReportsUseCase
    private let deleteReportUseCase: DeleteReportUseCase
    private let updateReportUseCase: UpdateReportUseCase
    private let tagRepository: any TagRepositoryProtocol
    
    // MARK: - Initialization
    init(
        getReportsUseCase: GetReportsUseCase,
        deleteReportUseCase: DeleteReportUseCase,
        updateReportUseCase: UpdateReportUseCase,
        tagRepository: any TagRepositoryProtocol
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        self.updateReportUseCase = updateReportUseCase
        self.tagRepository = tagRepository
        
        super.init(initialState: ReportsState())
        
        // Загружаем настройки
        loadSettings()
    }
    
    // MARK: - LoadableViewModel
    
    func load() async {
        await handle(.loadReports)
    }
    
    override func handle(_ event: ReportsEvent) async {
        switch event {
        case .loadReports:
            await loadReports()
        case .refreshReports:
            await loadReports()
        case .loadTags:
            await loadTags()
        case .toggleSelectionMode:
            state.isSelectionMode.toggle()
            if !state.isSelectionMode {
                state.selectedLocalReportIDs.removeAll()
            }
        case .toggleSelection(let id):
            if state.selectedLocalReportIDs.contains(id) {
                state.selectedLocalReportIDs.remove(id)
            } else {
                state.selectedLocalReportIDs.insert(id)
            }
        case .selectAllRegularReports:
            if state.selectedRegularPosts.count == state.regularReports.count {
                state.selectedLocalReportIDs.removeAll()
            } else {
                state.selectedLocalReportIDs = Set(state.regularReports.map { $0.id })
            }
        case .selectAllCustomReports:
            if state.selectedCustomPosts.count == state.customReports.count {
                state.selectedLocalReportIDs.removeAll()
            } else {
                state.selectedLocalReportIDs = Set(state.customReports.map { $0.id })
            }
        case .clearSelection:
            state.selectedLocalReportIDs.removeAll()
        case .deleteSelectedReports:
            await deleteSelectedReports()
        case .startEvaluation(let post):
            state.evaluatingPost = post
            state.showEvaluationSheet = true
        case .completeEvaluation(let results):
            await completeEvaluation(results: results)
        case .updateReevaluationSettings(let enabled):
            updateReevaluationSettings(enabled)
        case .clearError:
            state.error = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Проверить, можно ли оценить отчет
    func canEvaluateReport(_ post: DomainPost) -> Bool {
        Calendar.current.isDateInToday(post.date) && 
        !state.isSelectionMode && 
        (post.isEvaluated != true || state.allowCustomReportReevaluation) && 
        !post.goodItems.isEmpty
    }
    
    /// Проверить, оценен ли отчет
    func isReportEvaluated(_ post: DomainPost) -> Bool {
        post.isEvaluated == true && !state.allowCustomReportReevaluation
    }
    
    // MARK: - Private Methods
    
    private func loadReports() async {
        state.isLoading = true
        state.error = nil
        
        do {
            // Загружаем обычные отчеты
            let regularInput = GetReportsInput(
                date: Date(),
                type: .regular,
                includeExternal: false
            )
            let regularReports = try await getReportsUseCase.execute(input: regularInput)
            state.regularReports = regularReports
            
            // Загружаем кастомные отчеты
            let customInput = GetReportsInput(
                date: Date(),
                type: .custom,
                includeExternal: false
            )
            let customReports = try await getReportsUseCase.execute(input: customInput)
            state.customReports = customReports
            
            // Загружаем внешние отчеты
            let externalInput = GetReportsInput(
                date: Date(),
                type: nil,
                includeExternal: true
            )
            let allReports = try await getReportsUseCase.execute(input: externalInput)
            state.externalReports = allReports.filter { $0.isExternal == true }
            
        } catch {
            state.error = error
            Logger.error("Failed to load reports: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func loadTags() async {
        do {
            let goodTags = try await tagRepository.loadGoodTags()
            let badTags = try await tagRepository.loadBadTags()
            state.goodTags = goodTags
            state.badTags = badTags
        } catch {
            Logger.error("Failed to load tags: \(error)", log: Logger.ui)
        }
    }
    
    private func deleteSelectedReports() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let reportsToDelete = state.selectedRegularPosts + state.selectedCustomPosts
            
            for report in reportsToDelete {
                let input = DeleteReportInput(report: report)
                try await deleteReportUseCase.execute(input: input)
            }
            
            // Обновляем списки отчетов
            state.regularReports.removeAll { report in
                reportsToDelete.contains { $0.id == report.id }
            }
            state.customReports.removeAll { report in
                reportsToDelete.contains { $0.id == report.id }
            }
            
            // Очищаем выбор
            state.selectedLocalReportIDs.removeAll()
            state.isSelectionMode = false
            
        } catch {
            state.error = error
            Logger.error("Failed to delete selected reports: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func completeEvaluation(results: [Bool]) async {
        guard let post = state.evaluatingPost else { return }
        
        do {
            var updatedPost = post
            updatedPost.evaluationResults = results
            updatedPost.isEvaluated = true
            
            let input = UpdateReportInput(report: updatedPost)
            let _ = try await updateReportUseCase.execute(input: input)
            
            // Обновляем отчет в списке
            updateReportInLists(updatedPost)
            
            state.evaluatingPost = updatedPost
            
        } catch {
            state.error = error
            Logger.error("Failed to complete evaluation: \(error)", log: Logger.ui)
        }
        
        state.showEvaluationSheet = false
        state.evaluatingPost = nil
    }
    
    private func updateReportInLists(_ updatedPost: DomainPost) {
        // Обновляем в списке обычных отчетов
        if let index = state.regularReports.firstIndex(where: { $0.id == updatedPost.id }) {
            state.regularReports[index] = updatedPost
        }
        
        // Обновляем в списке кастомных отчетов
        if let index = state.customReports.firstIndex(where: { $0.id == updatedPost.id }) {
            state.customReports[index] = updatedPost
        }
    }
    
    private func loadSettings() {
        state.allowCustomReportReevaluation = UserDefaults.standard.bool(forKey: "allowCustomReportReevaluation")
    }
    
    private func updateReevaluationSettings(_ enabled: Bool) {
        state.allowCustomReportReevaluation = enabled
        UserDefaults.standard.set(enabled, forKey: "allowCustomReportReevaluation")
    }
} 