import Foundation
import WidgetKit
import Combine

extension Notification.Name {
    static let reportStatusDidChange = Notification.Name("ReportStatusDidChange")
}

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
    private var activityObserver: Any?
    
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
        
        // Подписка на смену активности периода (начало/конец окна отчётности)
        activityObserver = NotificationCenter.default.addObserver(
            forName: .reportPeriodActivityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Пересчитываем статус немедленно, чтобы убрать "заполни отчёт" после конца окна
            self?.updateStatus()
        }

        loadStatus()
        checkForNewDay()
        updateStatus()
    }

    deinit {
        if let observer = activityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func updateStatus() {
        // Сначала проверяем новый день
        checkForNewDay()

        // Синхронизируем флаг forceUnlock из хранилища на случай, если он был изменён другим инстансом менеджера
        let storedForceUnlock = localService.getForceUnlock()
        let forceUnlockChanged = (storedForceUnlock != forceUnlock)
        if forceUnlockChanged {
            forceUnlock = storedForceUnlock
        }

        let today = Calendar.current.startOfDay(for: Date())
        let isPeriodActive = factory.isReportPeriodActive()

        // Получаем отчеты за сегодня
        let posts = postsProvider.getPosts()
        // Если посты ещё не загружены (на старте приложения), определяем статус по активности периода
        if posts.isEmpty {
            let newStatus: ReportStatus = forceUnlock ? .notStarted : (isPeriodActive ? .notStarted : .notCreated)
            if reportStatus != newStatus {
                reportStatus = newStatus
                saveStatus()
                updateDependencies(newStatus)
            } else if forceUnlockChanged {
                // Статус не изменился, но forceUnlock изменился — уведомим UI
                updateDependencies(newStatus)
            }
            return
        }
        let regular = posts.first(where: { 
            $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) 
        })

        // Если включен forceUnlock
        if forceUnlock {
            if regular?.published == true {
                // Отчет уже отправлен — одноразовая разблокировка должна быть погашена
                forceUnlock = false
                localService.saveForceUnlock(false)
                // Продолжаем обычный расчет статуса ниже
            } else {
                // Отчет не отправлен — удерживаем статус notStarted и выходим
                let newStatus: ReportStatus = .notStarted
                if reportStatus != newStatus {
                    reportStatus = newStatus
                    saveStatus()
                    updateDependencies(newStatus)
                } else if forceUnlockChanged {
                    // Статус не изменился, но forceUnlock изменился — уведомим UI
                    updateDependencies(newStatus)
                }
                return
            }
        }

        // Определяем новый статус (без принудительной разблокировки)
        let newStatus = factory.createStatus(
            hasRegularReport: regular != nil,
            isReportPublished: regular?.published ?? false,
            isPeriodActive: isPeriodActive,
            forceUnlock: false
        )
        
        // Удалено: не выполняем принудительный сброс .sent -> .notStarted, если не найден отчет за сегодня
        // Сброс статуса выполняется по правилам нового дня в checkForNewDay()
        
        // Обновляем только если статус изменился
        if reportStatus != newStatus {
            reportStatus = newStatus
            saveStatus()
            updateDependencies(newStatus)
        } else if forceUnlockChanged {
            // Статус не изменился, но forceUnlock изменился — уведомим UI
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
        // Разблокировать создание отчета без удаления локальных данных
        // Устанавливаем флаг принудительной разблокировки и сохраняем
        if forceUnlock == false { forceUnlock = true }
        // Если у сегодняшнего регулярного отчета стоит published=true, снимаем публикацию, чтобы разрешить редактирование без удаления данных
        let today = Calendar.current.startOfDay(for: Date())
        var posts = postsProvider.getPosts()
        if let idx = posts.firstIndex(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            if posts[idx].published == true {
                posts[idx].published = false
                postsProvider.updatePosts(posts)
            }
        }
        // Немедленно сохраняем флаг и новый статус (даже если они уже такие же)
        let newStatus: ReportStatus = .notStarted
        reportStatus = newStatus
        localService.saveForceUnlock(true)
        saveStatus()
        updateDependencies(newStatus)
        timerService.updateReportStatus(reportStatus)
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
        // Уведомляем подписчиков (главный экран и др.), что статус изменился
        NotificationCenter.default.post(name: .reportStatusDidChange, object: self, userInfo: ["status": status.rawValue])
    }
} 