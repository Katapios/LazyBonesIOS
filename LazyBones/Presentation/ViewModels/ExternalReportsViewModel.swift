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
        }
    }
    
    // MARK: - Private Methods
    
    private func loadReports() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let input = GetReportsInput(
                date: state.selectedDate,
                type: .external,
                includeExternal: true
            )
            let reports = try await getReportsUseCase.execute(input: input)
            state.reports = reports
            
            // Проверяем подключение к Telegram
            let settings = telegramIntegrationService.loadTelegramSettings()
            state.telegramConnected = settings.token != nil && !settings.token!.isEmpty
            
            updateButtonStates()
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func refreshFromTelegram() async {
        state.isRefreshing = true
        state.error = nil
        
        // Используем completion-based API для совместимости
        await withCheckedContinuation { continuation in
            telegramIntegrationService.fetchExternalPosts { success in
                Task { @MainActor in
                    if success {
                        await self.loadReports()
                    } else {
                        self.state.error = NSError(domain: "ExternalReports", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки из Telegram"])
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
        
        await withCheckedContinuation { continuation in
            telegramIntegrationService.deleteAllBotMessages { success in
                Task { @MainActor in
                    if success {
                        self.state.reports.removeAll()
                        self.telegramIntegrationService.saveExternalPosts()
                    } else {
                        self.state.error = NSError(domain: "ExternalReports", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ошибка очистки истории"])
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
} 