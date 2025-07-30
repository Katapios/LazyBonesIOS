import Foundation
import BackgroundTasks

/// Протокол сервиса фоновых задач
protocol BackgroundTaskServiceProtocol {
    func registerBackgroundTasks() throws
    func scheduleSendReportTask() throws
    func handleSendReportTask(_ task: BGAppRefreshTask) async
}

/// Ошибки сервиса фоновых задач
enum BackgroundTaskServiceError: Error, LocalizedError {
    case registrationFailed
    case schedulingFailed
    case invalidTaskIdentifier
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register background task"
        case .schedulingFailed:
            return "Failed to schedule background task"
        case .invalidTaskIdentifier:
            return "Invalid task identifier"
        }
    }
}

/// Реализация сервиса фоновых задач
class BackgroundTaskService: BackgroundTaskServiceProtocol {
    
    private let taskIdentifier = AppConfig.backgroundTaskIdentifier
    private let userDefaultsManager: UserDefaultsManager
    
    init(userDefaultsManager: UserDefaultsManager = .shared) {
        self.userDefaultsManager = userDefaultsManager
    }
    
    // MARK: - BackgroundTaskServiceProtocol
    
    func registerBackgroundTasks() throws {
        Logger.info("Registering background tasks", log: Logger.background)
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            Logger.info("Background task triggered: \(self.taskIdentifier)", log: Logger.background)
            Task {
                await self.handleSendReportTask(task as! BGAppRefreshTask)
            }
        }
        Logger.info("Background tasks registered successfully", log: Logger.background)
    }
    
    func scheduleSendReportTask() throws {
        Logger.info("Scheduling send report background task", log: Logger.background)
        
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        let earliestBeginDate = calculateEarliestBeginDate()
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.info("Background task scheduled for: \(earliestBeginDate)", log: Logger.background)
        } catch {
            Logger.error("Failed to schedule background task: \(error)", log: Logger.background)
            throw BackgroundTaskServiceError.schedulingFailed
        }
    }
    
    func handleSendReportTask(_ task: BGAppRefreshTask) async {
        Logger.info("Handling send report background task", log: Logger.background)
        
        // Устанавливаем обработчик завершения задачи
        task.expirationHandler = {
            Logger.warning("Background task expired", log: Logger.background)
            task.setTaskCompleted(success: false)
        }
        
        do {
            // Проверяем настройки автоотправки
            let (enabled, _) = userDefaultsManager.loadAutoSendSettings()
            
            if enabled {
                Logger.info("Auto-send enabled, processing reports", log: Logger.background)
                await processAutoSendReports()
            } else {
                Logger.info("Auto-send disabled, skipping", log: Logger.background)
            }
            
            // Планируем следующую задачу
            try scheduleSendReportTask()
            
            // Завершаем задачу успешно
            task.setTaskCompleted(success: true)
            Logger.info("Background task completed successfully", log: Logger.background)
            
        } catch {
            Logger.error("Background task failed: \(error)", log: Logger.background)
            task.setTaskCompleted(success: false)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateEarliestBeginDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Планируем на 22:01 сегодня или завтра
        let today2201 = calendar.date(bySettingHour: 22, minute: 1, second: 0, of: now)!
        let today2359 = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)!
        
        var earliest: Date
        
        if now < today2201 {
            // Если сейчас раньше 22:01, планируем на 22:01 сегодня
            earliest = today2201
        } else if now >= today2201 && now <= today2359 {
            // Если сейчас в промежутке 22:01-23:59, планируем на сейчас
            earliest = now
        } else {
            // Если сейчас после 23:59, планируем на 22:01 завтра
            let tomorrow2201 = calendar.date(byAdding: .day, value: 1, to: today2201)!
            earliest = tomorrow2201
        }
        
        return earliest
    }
    
    private func processAutoSendReports() async {
        Logger.info("Processing auto-send reports", log: Logger.background)
        
        // Используем PostStore для автоотправки отчетов
        let store = PostStore.shared
        store.autoSendAllReportsForToday {
            Logger.info("Auto-send reports sent", log: Logger.background)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Проверить статус фоновых задач
    func checkBackgroundTaskStatus() async -> Bool {
        // BGTaskScheduler не предоставляет прямой доступ к зарегистрированным идентификаторам
        // Возвращаем true, предполагая что задача зарегистрирована
        return true
    }
    
    /// Отменить все фоновые задачи
    func cancelAllBackgroundTasks() {
        Logger.info("Cancelling all background tasks", log: Logger.background)
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
} 