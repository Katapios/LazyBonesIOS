import Foundation
import SwiftUI

/// Новый MainViewModel с Clean Architecture
@MainActor
class MainViewModelNew: BaseViewModel<MainState, MainEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // MARK: - Dependencies
    private let getReportsUseCase: GetReportsUseCase
    private let updateStatusUseCase: UpdateStatusUseCase
    private let settingsRepository: any SettingsRepositoryProtocol
    private let timerService: any PostTimerServiceProtocol
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var statusChangeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    init(
        getReportsUseCase: GetReportsUseCase,
        updateStatusUseCase: UpdateStatusUseCase,
        settingsRepository: any SettingsRepositoryProtocol,
        timerService: any PostTimerServiceProtocol
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.updateStatusUseCase = updateStatusUseCase
        self.settingsRepository = settingsRepository
        self.timerService = timerService
        
        super.init(initialState: MainState())
        
        setupTimer()

        // Подписываемся на изменения статуса (разблокировка из настроек и др.)
        statusChangeObserver = NotificationCenter.default.addObserver(
            forName: .reportStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handle(.updateStatus)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        if let token = statusChangeObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    // MARK: - LoadableViewModel
    
    func load() async {
        await handle(.loadData)
    }
    
    override func handle(_ event: MainEvent) async {
        switch event {
        case .loadData:
            await loadData()
        case .updateStatus:
            await updateStatus()
        case .checkForNewDay:
            await checkForNewDay()
        case .updateTime:
            await updateTime()
        case .switchToPlanning:
            // Это будет обрабатываться в View через AppCoordinator
            break
        case .clearError:
            state.error = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func loadData() async {
        state.isLoading = true
        state.error = nil
        
        do {
            // Загружаем настройки уведомлений
            let notificationSettings = try await settingsRepository.loadNotificationSettings()
            state.notificationStartHour = notificationSettings.startHour
            state.notificationEndHour = notificationSettings.endHour
            
            // Загружаем текущий статус
            let reportStatus = try await settingsRepository.loadReportStatus()
            state.reportStatus = reportStatus
            // Загружаем forceUnlock
            let forceUnlock = try await settingsRepository.loadForceUnlock()
            state.forceUnlock = forceUnlock
            
            // Загружаем отчеты за сегодня
            await loadTodayReports()
            
            // Обновляем время
            await updateTime()
            
            // Обновляем таймер
            timerService.updateReportStatus(reportStatus)
            
        } catch {
            state.error = error
            Logger.error("Failed to load main data: \(error)", log: Logger.ui)
        }
        
        state.isLoading = false
    }
    
    private func loadTodayReports() async {
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let input = GetReportsInput(date: today, type: nil, includeExternal: false)
            let reports = try await getReportsUseCase.execute(input: input)
            
            // Находим отчет за сегодня
            state.todayReport = reports.first { report in
                Calendar.current.isDate(report.date, inSameDayAs: today)
            }
            
            // Вычисляем количество хороших и плохих дел
            calculateProgressCounts(reports: reports, for: today)
            
        } catch {
            state.error = error
            Logger.error("Failed to load today reports: \(error)", log: Logger.ui)
        }
    }
    
    private func calculateProgressCounts(reports: [DomainPost], for date: Date) {
        var goodCount = 0
        var badCount = 0
        
        for report in reports {
            guard Calendar.current.isDate(report.date, inSameDayAs: date) else { continue }
            
            switch report.type {
            case .regular:
                // Обычный отчет: считаем хорошие и плохие дела
                goodCount += report.goodItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
                badCount += report.badItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
                
            case .custom:
                // Кастомный отчет: считаем только если оценен
                if report.isEvaluated == true, let results = report.evaluationResults {
                    goodCount += results.filter { $0 }.count
                    badCount += results.filter { !$0 }.count
                }
                
            case .external, .iCloud:
                // Внешние отчеты не учитываем в прогрессе главного экрана
                break
            }
        }
        
        state.goodCountToday = goodCount
        state.badCountToday = badCount
    }
    
    private func updateStatus() async {
        do {
            let input = UpdateStatusInput(checkNewDay: true)
            let newStatus = try await updateStatusUseCase.execute(input: input)
            state.reportStatus = newStatus
            // Синхронизируем forceUnlock из SettingsRepository, т.к. он может меняться вне VM
            let forceUnlock = try await settingsRepository.loadForceUnlock()
            state.forceUnlock = forceUnlock
            
            // Обновляем таймер с новым статусом
            timerService.updateReportStatus(newStatus)
            
            // Перезагружаем отчеты за сегодня
            await loadTodayReports()
            
        } catch {
            state.error = error
            Logger.error("Failed to update status: \(error)", log: Logger.ui)
        }
    }
    
    private func checkForNewDay() async {
        await updateStatus()
    }
    
    private func updateTime() async {
        // Обновляем текущее время
        state.currentTime = Date()
        
        // Получаем время от таймер-сервиса
        state.timeLeft = timerService.timeLeft
        state.timeProgress = timerService.timeProgress
        // Исключение для отправленного отчета: прогресс = 0.0
        if state.reportStatus == .sent { state.timeProgress = 0.0 }
        
        // Вычисляем подпись таймера
        state.timerLabel = calculateTimerLabel()
        
        // Вычисляем только время (без подписи)
        state.timerTimeTextOnly = extractTimeOnly(from: state.timeLeft)
    }
    
    private func calculateTimerLabel() -> String {
        let calendar = Calendar.current
        let now = state.currentTime
        let start = calendar.date(
            bySettingHour: state.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: state.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(state.currentDay, inSameDayAs: today) {
            return "Новый день"
        }
        
        if state.reportStatus == .sent || state.reportStatus == .notCreated || state.reportStatus == .notSent {
            return "До старта"
        } else if now < start {
            return "До старта"
        } else if now >= start && now < end {
            return "До конца"
        } else {
            return "Время истекло"
        }
    }
    
    private func extractTimeOnly(from timeLeft: String) -> String {
        if let range = timeLeft.range(of: ": ") {
            return String(timeLeft[range.upperBound...])
        }
        return timeLeft
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.handle(.updateTime)
            }
        }
    }
} 