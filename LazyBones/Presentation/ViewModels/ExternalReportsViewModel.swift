import Foundation
import SwiftUI

/// ViewModel для внешних отчетов из Telegram
@MainActor
class ExternalReportsViewModel: BaseViewModel<ExternalReportsState, ExternalReportsEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    private let deleteReportUseCase: any DeleteReportUseCaseProtocol
    private let telegramIntegrationService: any TelegramIntegrationServiceProtocol
    
    init(
        getReportsUseCase: any GetReportsUseCaseProtocol,
        deleteReportUseCase: any DeleteReportUseCaseProtocol,
        telegramIntegrationService: any TelegramIntegrationServiceProtocol
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        self.telegramIntegrationService = telegramIntegrationService
        super.init(initialState: ExternalReportsState())
    }
    
    // MARK: - LoadableViewModel
    
    func load() async {
        await loadReports()
    }
    
    override func handle(_ event: ExternalReportsEvent) async {
        switch event {
        case .loadReports:
            await loadReports()
        case .refreshFromTelegram:
            await refreshFromTelegram()
        case .clearHistory:
            await clearHistory()
        case .openTelegramGroup:
            await openTelegramGroup()
        case .handleTelegramMessage(let message):
            await handleTelegramMessage(message)
        case .selectDate(let date):
            state.selectedDate = date
            await loadReports()
        case .toggleSelectionMode:
            state.isSelectionMode.toggle()
            if !state.isSelectionMode {
                state.selectedReportIDs.removeAll()
            }
        case .selectReport(let id):
            if state.selectedReportIDs.contains(id) {
                state.selectedReportIDs.remove(id)
            } else {
                state.selectedReportIDs.insert(id)
            }
        case .selectAllReports:
            state.selectedReportIDs = Set(state.reports.map { $0.id })
        case .deselectAllReports:
            state.selectedReportIDs.removeAll()
        case .deleteSelectedReports:
            await deleteSelectedReports()
        case .clearError:
            state.error = nil
        case .resetLastUpdateId:
            await resetLastUpdateId()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadReports() async {
        state.isLoading = true
        state.error = nil
        
        // Загружаем сохраненные внешние сообщения
        telegramIntegrationService.loadExternalPosts()
        
        // Загружаем внешние отчеты напрямую из telegramIntegrationService
        let externalPosts = telegramIntegrationService.externalPosts
        state.reports = externalPosts.map { post in
            // Конвертируем Post в DomainPost
            return DomainPost(
                id: post.id,
                date: post.date,
                goodItems: post.goodItems,
                badItems: post.badItems,
                published: post.published,
                voiceNotes: post.voiceNotes.map { voiceNote in
                    return DomainVoiceNote(
                        id: voiceNote.id,
                        url: URL(fileURLWithPath: voiceNote.path),
                        duration: 0.0
                    )
                },
                type: post.type,
                isEvaluated: post.isEvaluated,
                evaluationResults: post.evaluationResults,
                authorUsername: post.authorUsername,
                authorFirstName: post.authorFirstName,
                authorLastName: post.authorLastName,
                isExternal: post.isExternal,
                externalVoiceNoteURLs: post.externalVoiceNoteURLs,
                externalText: post.externalText,
                externalMessageId: post.externalMessageId,
                authorId: post.authorId
            )
        }
        
        // Проверяем подключение к Telegram
        let settings = telegramIntegrationService.loadTelegramSettings()
        state.telegramConnected = settings.token != nil && !settings.token!.isEmpty
        
        updateButtonStates()
        
        Logger.info("Loaded \(state.reports.count) saved external reports", log: Logger.telegram)
        
        state.isLoading = false
    }
    
    private func refreshFromTelegram() async {
        state.isRefreshing = true
        state.error = nil
        
        // Проверяем подключение к Telegram перед попыткой загрузки
        let settings = telegramIntegrationService.loadTelegramSettings()
        guard settings.token != nil && !settings.token!.isEmpty else {
            state.error = NSError(domain: "ExternalReports", code: 3, userInfo: [NSLocalizedDescriptionKey: "Telegram не настроен. Проверьте настройки в разделе Settings."])
            state.isRefreshing = false
            return
        }
        
        // Принудительно обновляем TelegramService для получения актуального токена
        telegramIntegrationService.refreshTelegramService()
        
        // Используем completion-based API для совместимости
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            telegramIntegrationService.fetchExternalPosts { success in
                Task { @MainActor in
                    if success {
                        // Обновляем список отчетов из telegramIntegrationService
                        self.state.reports = self.telegramIntegrationService.externalPosts.map { post in
                            // Конвертируем Post в DomainPost
                            return DomainPost(
                                id: post.id,
                                date: post.date,
                                goodItems: post.goodItems,
                                badItems: post.badItems,
                                published: post.published,
                                voiceNotes: post.voiceNotes.map { voiceNote in
                                    return DomainVoiceNote(
                                        id: voiceNote.id,
                                        url: URL(fileURLWithPath: voiceNote.path),
                                        duration: 0.0
                                    )
                                },
                                type: post.type,
                                isEvaluated: post.isEvaluated,
                                evaluationResults: post.evaluationResults,
                                authorUsername: post.authorUsername,
                                authorFirstName: post.authorFirstName,
                                authorLastName: post.authorLastName,
                                isExternal: post.isExternal,
                                externalVoiceNoteURLs: post.externalVoiceNoteURLs,
                                externalText: post.externalText,
                                externalMessageId: post.externalMessageId,
                                authorId: post.authorId
                            )
                        }
                        
                        // Обновляем состояние кнопок
                        self.updateButtonStates()
                        
                        Logger.info("Successfully refreshed \(self.state.reports.count) reports from Telegram", log: Logger.telegram)
                    } else {
                        self.state.error = NSError(domain: "ExternalReports", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки из Telegram. Проверьте подключение к интернету и настройки Telegram."])
                        Logger.error("Failed to refresh reports from Telegram", log: Logger.telegram)
                    }
                    self.state.isRefreshing = false
                    continuation.resume()
                }
            }
        }
    }
    
    private func clearHistory() async {
        state.isLoading = true
        state.error = nil
        
        // Проверяем подключение к Telegram перед попыткой очистки
        let settings = telegramIntegrationService.loadTelegramSettings()
        guard settings.token != nil && !settings.token!.isEmpty else {
            state.error = NSError(domain: "ExternalReports", code: 3, userInfo: [NSLocalizedDescriptionKey: "Telegram не настроен. Проверьте настройки в разделе Settings."])
            state.isLoading = false
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            telegramIntegrationService.deleteAllBotMessages { success in
                Task { @MainActor in
                    if success {
                        // Очищаем список отчетов в UI
                        self.state.reports.removeAll()
                        
                        // Очищаем выбор, если был включен режим выбора
                        self.state.selectedReportIDs.removeAll()
                        self.state.isSelectionMode = false
                        
                        // Обновляем состояние кнопок
                        self.updateButtonStates()
                        
                        // После успешной очистки перезагружаем состояние
                        // чтобы синхронизировать UI с сервисом
                        await self.loadReports()
                        
                        Logger.info("Successfully cleared external reports history", log: Logger.telegram)
                    } else {
                        self.state.error = NSError(domain: "ExternalReports", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ошибка очистки истории. Проверьте подключение к интернету и настройки Telegram."])
                        Logger.error("Failed to clear external reports history", log: Logger.telegram)
                    }
                    self.state.isLoading = false
                    continuation.resume()
                }
            }
        }
    }
    
    private func openTelegramGroup() async {
        // Открываем группу в Telegram
        if let url = URL(string: "https://t.me/+Ny08CEMnQJplMGJi") {
            // В SwiftUI это будет обрабатываться через View
            // Здесь просто логируем действие
            Logger.info("Opening Telegram group: \(url)", log: Logger.telegram)
        }
    }
    
    private func handleTelegramMessage(_ message: TelegramMessage) async {
        // Конвертируем сообщение в отчет
        if let post = telegramIntegrationService.convertTelegramMessageToPost(message) {
            // Добавляем в список внешних отчетов
            telegramIntegrationService.externalPosts.append(post)
            telegramIntegrationService.saveExternalPosts()
            
            // Обновляем список
            await loadReports()
        }
    }
    
    private func deleteSelectedReports() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let reportsToDelete = state.reports.filter { state.selectedReportIDs.contains($0.id) }
            
            for report in reportsToDelete {
                let input = DeleteReportInput(report: report)
                try await deleteReportUseCase.execute(input: input)
            }
            
            // Удаляем отчеты из списка
            state.reports.removeAll { state.selectedReportIDs.contains($0.id) }
            
            // Очищаем выбор
            state.selectedReportIDs.removeAll()
            state.isSelectionMode = false
            
            updateButtonStates()
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func updateButtonStates() {
        // Можно обновить из Telegram, если есть подключение
        let settings = telegramIntegrationService.loadTelegramSettings()
        state.telegramConnected = settings.token != nil && !settings.token!.isEmpty
        
        // canClearHistory вычисляется автоматически в state
    }
    
    private func resetLastUpdateId() async {
        Logger.info("Resetting lastUpdateId for debugging", log: Logger.telegram)
        telegramIntegrationService.resetLastUpdateId()
        
        // Показываем сообщение пользователю
        state.error = NSError(domain: "ExternalReports", code: 0, userInfo: [NSLocalizedDescriptionKey: "ID обновлений сброшен. Теперь можно получить все сообщения заново."])
        
        // Очищаем ошибку через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { @MainActor in
                self.state.error = nil
            }
        }
    }
}
