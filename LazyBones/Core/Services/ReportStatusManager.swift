import Foundation
import WidgetKit
import Combine

/// Протокол для получения отчетов
protocol PostsProviderProtocol {
    func getPosts() -> [Post]
    func updatePosts(_ posts: [Post])
}

/// Протокол для управления статусом отчетов
protocol ReportStatusManagerProtocol: ObservableObject {
    var reportStatus: ReportStatus { get }
    var forceUnlock: Bool { get set }
    var currentDay: Date { get }
    
    func updateStatus()
    func checkForNewDay()
    func unlockReportCreation()
    func loadStatus()
    func saveStatus()
}

/// Менеджер статуса отчетов
class ReportStatusManager: ReportStatusManagerProtocol {
    
    // MARK: - Published Properties
    @Published var reportStatus: ReportStatus = .notStarted
    @Published var forceUnlock: Bool = false
    @Published var currentDay: Date = Calendar.current.startOfDay(for: Date())
    
    // MARK: - Dependencies
    private let localService: LocalReportService
    private let timerService: PostTimerServiceProtocol
    private let notificationService: PostNotificationServiceProtocol
    private let factory: ReportStatusFactory
    private let postsProvider: PostsProviderProtocol
    
    // MARK: - Initialization
    init(
        localService: LocalReportService,
        timerService: PostTimerServiceProtocol,
        notificationService: PostNotificationServiceProtocol,
        postsProvider: PostsProviderProtocol,
        factory: ReportStatusFactory = ReportStatusFactory()
    ) {
        self.localService = localService
        self.timerService = timerService
        self.notificationService = notificationService
        self.postsProvider = postsProvider
        self.factory = factory
        
        loadStatus()
        checkForNewDay()
        updateStatus()
    }
    
    // MARK: - Public Methods
    
    func updateStatus() {
        // Сначала проверяем новый день
        checkForNewDay()
        
        if forceUnlock {
            let newStatus: ReportStatus = .notStarted
            if reportStatus != newStatus {
                reportStatus = newStatus
                saveStatus()
                updateDependencies(newStatus)
            }
            return
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let isPeriodActive = factory.isReportPeriodActive()
        
        // Получаем отчеты за сегодня
        let posts = postsProvider.getPosts()
        let regular = posts.first(where: { 
            $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) 
        })
        
        // Определяем новый статус
        let newStatus = factory.createStatus(
            hasRegularReport: regular != nil,
            isReportPublished: regular?.published ?? false,
            isPeriodActive: isPeriodActive,
            forceUnlock: forceUnlock
        )
        
        // Принудительно сбрасываем статус, если нет отчетов за сегодня
        if regular == nil && (reportStatus == .sent || reportStatus == .done) {
            reportStatus = .notStarted
            saveStatus()
            updateDependencies(.notStarted)
            return
        }
        
        // Обновляем только если статус изменился
        if reportStatus != newStatus {
            reportStatus = newStatus
            saveStatus()
            updateDependencies(newStatus)
        }
    }
    
    func checkForNewDay() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Если наступил новый день
        if !calendar.isDate(currentDay, inSameDayAs: today) {
            // Сбрасываем статус на новый день
            if factory.shouldResetOnNewDay(reportStatus) {
                reportStatus = .notStarted
                saveStatus()
                updateDependencies(.notStarted)
            }
            
            // Сбрасываем forceUnlock для нового дня
            if forceUnlock {
                forceUnlock = false
                localService.saveForceUnlock(false)
            }
            
            // Обновляем текущий день
            currentDay = today
            
            // Обновляем виджеты
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func unlockReportCreation() {
        let today = Calendar.current.startOfDay(for: Date())
        let posts = postsProvider.getPosts()
        
        // Удаляем опубликованный отчет за сегодня
        if let publishedIndex = posts.firstIndex(where: { 
            $0.type == .regular && 
            Calendar.current.isDate($0.date, inSameDayAs: today) && 
            $0.published 
        }) {
            var updatedPosts = posts
            updatedPosts.remove(at: publishedIndex)
            postsProvider.updatePosts(updatedPosts)
            
            updateStatus()
            timerService.updateReportStatus(reportStatus)
        }
    }
    
    func loadStatus() {
        reportStatus = localService.getReportStatus()
        forceUnlock = localService.getForceUnlock()
        timerService.updateReportStatus(reportStatus)
    }
    
    func saveStatus() {
        localService.saveReportStatus(reportStatus)
        localService.saveForceUnlock(forceUnlock)
    }
    
    // MARK: - Private Methods
    
    private func updateDependencies(_ status: ReportStatus) {
        timerService.updateReportStatus(status)
        WidgetCenter.shared.reloadAllTimelines()
        notificationService.scheduleNotificationsIfNeeded()
    }
} 