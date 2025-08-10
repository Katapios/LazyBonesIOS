import Foundation
import UIKit

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
    private let postTelegramService: PostTelegramServiceProtocol
    
    // MARK: - Initialization
    init(
        getReportsUseCase: GetReportsUseCase,
        deleteReportUseCase: DeleteReportUseCase,
        updateReportUseCase: UpdateReportUseCase,
        tagRepository: any TagRepositoryProtocol,
        postTelegramService: PostTelegramServiceProtocol = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self)!
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        self.updateReportUseCase = updateReportUseCase
        self.tagRepository = tagRepository
        self.postTelegramService = postTelegramService
        
        super.init(initialState: ReportsState())
        
        // Загружаем настройки
        loadSettings()

        // Подписка на изменения тегов
        NotificationCenter.default.addObserver(self, selector: #selector(handleTagsDidChange), name: .tagsDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        case .sendCustomReport(let post):
            await sendCustomReport(post)
        }
    }
    
    // MARK: - Public Methods
    
    /// Переключить режим выбора
    func toggleSelectionMode() {
        state.isSelectionMode.toggle()
        if !state.isSelectionMode {
            state.selectedLocalReportIDs.removeAll()
        }
    }
    
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
    
    // MARK: - Notifications
    @objc private func handleTagsDidChange() {
        Task { [weak self] in
            await self?.loadTags()
        }
    }

    // MARK: - Sending Custom Report
    private func sendCustomReport(_ post: DomainPost) async {
        // Предусловия: должен быть сохранённый план и выполнена оценка
        if post.goodItems.isEmpty {
            state.error = NSError(domain: "Reports", code: 1, userInfo: [NSLocalizedDescriptionKey: "Сначала сохраните план"])
            return
        }
        if post.isEvaluated != true {
            state.error = NSError(domain: "Reports", code: 2, userInfo: [NSLocalizedDescriptionKey: "Сначала оцените отчет"])
            return
        }

        state.isLoading = true
        defer { state.isLoading = false }

        let message = formatCustomReportMessage(post)

        let success: Bool = await withCheckedContinuation { continuation in
            postTelegramService.sendToTelegram(text: message) { ok in
                continuation.resume(returning: ok)
            }
        }

        if success {
            do {
                var updated = post
                updated.published = true
                let input = UpdateReportInput(report: updated)
                _ = try await updateReportUseCase.execute(input: input)
                updateReportInLists(updated)
                NotificationCenter.default.post(name: .reportStatusDidChange, object: nil)
            } catch {
                state.error = error
            }
        } else {
            state.error = NSError(domain: "Reports", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось отправить в Telegram"])
        }
    }

    private func formatCustomReportMessage(_ report: DomainPost) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .full
        let dateStr = df.string(from: report.date)
        let deviceName = UIDevice.current.name

        var message = "\u{1F4C5} <b>Кастомный отчет — \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"

        if !report.goodItems.isEmpty {
            message += "<b>✅ План:</b>\n"
            if let results = report.evaluationResults, results.count == report.goodItems.count {
                for (idx, item) in report.goodItems.enumerated() {
                    let mark = results[idx] ? "✅" : "❌"
                    message += "\(idx + 1). \(mark) \(item)\n"
                }
            } else {
                for (idx, item) in report.goodItems.enumerated() {
                    message += "\(idx + 1). \(item)\n"
                }
            }
            message += "\n"
        }

        if !report.badItems.isEmpty {
            message += "<b>❌ Я не молодец:</b>\n"
            for (idx, item) in report.badItems.enumerated() {
                message += "\(idx + 1). \(item)\n"
            }
        }

        if let results = report.evaluationResults, !results.isEmpty {
            let done = results.filter { $0 }.count
            let total = results.count
            let percent = Int((Double(done) / Double(total)) * 100)
            message += "\n📊 <i>Выполнено: \(done)/\(total) (\(percent)%)</i>"
        }

        return message
    }
}