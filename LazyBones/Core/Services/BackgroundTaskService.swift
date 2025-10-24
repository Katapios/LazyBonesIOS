import Foundation
@preconcurrency import BackgroundTasks
import UIKit

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
class BackgroundTaskService: BackgroundTaskServiceProtocol, @unchecked Sendable {
    // MARK: - Singleton
    static let shared = BackgroundTaskService()
    
    // MARK: - Properties
    private let taskIdentifier: String
    private let userDefaultsManager: UserDefaultsManager
    private let autoSendService: AutoSendServiceType
    private let registrationQueue = DispatchQueue(label: "\(AppConfig.mainBundleId).backgroundTaskRegistration")
    private var isRegistered = false
    
    // MARK: - Initialization
    private init() {
        // Initialize with default values first
        self.userDefaultsManager = .shared
        self.taskIdentifier = AppConfig.backgroundTaskIdentifier
        
        // Try to resolve autoSendService, but don't force unwrap
        if let autoSendService = DependencyContainer.shared.resolve(AutoSendServiceType.self) {
            self.autoSendService = autoSendService
        } else {
            // Fallback to a default implementation if resolution fails
            Logger.error("Failed to resolve AutoSendService, using fallback", log: Logger.background)
            let userDefaultsManager = UserDefaultsManager.shared
            // Create a default TelegramService with empty token for fallback
            let telegramService = TelegramService(token: "")
            let postTelegramService = PostTelegramService(
                telegramService: telegramService,
                userDefaultsManager: userDefaultsManager
            )
            self.autoSendService = AutoSendService(
                userDefaultsManager: userDefaultsManager,
                postTelegramService: postTelegramService
            )
        }
        
        Logger.info("BackgroundTaskService initialized with identifier: \(self.taskIdentifier)", log: Logger.background)
    }
    
    // MARK: - BackgroundTaskServiceProtocol
    
    func registerBackgroundTasks() throws {
        #if targetEnvironment(simulator)
        Logger.info("Skipping BGTask registration on Simulator", log: Logger.background)
        isRegistered = true // Помечаем как зарегистрированный для симулятора
        return
        #else
        var registrationError: Error?
        
        registrationQueue.sync {
            guard !self.isRegistered else {
                Logger.info("Background tasks already registered, skipping", log: Logger.background)
                return
            }
            
            Logger.info("Bundle ID at registration: \(Bundle.main.bundleIdentifier ?? "nil")", log: Logger.background)
            Logger.info("Registering background tasks with identifier: \(self.taskIdentifier)", log: Logger.background)
            
            let success = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: self.taskIdentifier,
                using: nil
            ) { [weak self] task in
                guard let self = self else {
                    task.setTaskCompleted(success: false)
                    return
                }
                
                Logger.info("Background task triggered: \(self.taskIdentifier)", log: Logger.background)
                
                Task {
                    if let refreshTask = task as? BGAppRefreshTask {
                        await self.handleSendReportTask(refreshTask)
                    } else {
                        Logger.error("Unexpected task type: \(type(of: task))", log: Logger.background)
                        task.setTaskCompleted(success: false)
                    }
                }
            }
            
            if success {
                self.isRegistered = true
                Logger.info("Background tasks registered successfully", log: Logger.background)
            } else {
                Logger.error("Failed to register background task", log: Logger.background)
                registrationError = BackgroundTaskServiceError.registrationFailed
            }
        }
        
        if let error = registrationError {
            throw error
        }
        #endif
    }
    
    func scheduleSendReportTask() throws {
        #if targetEnvironment(simulator)
        Logger.info("Skipping BGTask scheduling on Simulator (using DEBUG timer instead)", log: Logger.background)
        return
        #else
        
        // Availability guard
        if #unavailable(iOS 13.0) {
            Logger.warning("BGTaskScheduler is unavailable on this iOS version", log: Logger.background)
            return
        }
        
        // Verify Background App Refresh is available
        let refreshStatus = UIApplication.shared.backgroundRefreshStatus
        Logger.info("Background refresh status: \(refreshStatus.rawValue)", log: Logger.background)
        
        switch refreshStatus {
        case .available:
            Logger.info("Background App Refresh is available", log: Logger.background)
        case .denied:
            Logger.warning("Background App Refresh is denied by user; skipping BGTask scheduling", log: Logger.background)
            return
        case .restricted:
            Logger.warning("Background App Refresh is restricted by system; skipping BGTask scheduling", log: Logger.background)
            return
        @unknown default:
            Logger.warning("Unknown Background App Refresh status: \(refreshStatus.rawValue); skipping BGTask scheduling", log: Logger.background)
            return
        }
        
        // Verify Info.plist contains permitted identifiers
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        Logger.info("Permitted BGTask IDs: \(permitted)", log: Logger.background)
        Logger.info("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")", log: Logger.background)
        guard permitted.contains(self.taskIdentifier) else {
            Logger.error("BGTask identifier not permitted in Info.plist: \(self.taskIdentifier)", log: Logger.background)
            return
        }
        
        Logger.info("Scheduling send report background task", log: Logger.background)
        
        // First, cancel any existing tasks to avoid duplicates
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        // Ensure request creation and submission on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [taskIdentifier = self.taskIdentifier] in
                let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
                request.earliestBeginDate = self.safeEarliestBeginDate()
                do {
                    try BGTaskScheduler.shared.submit(request)
                    Logger.info("✅ Background task scheduled (main thread)", log: Logger.background)
                } catch {
                    Logger.error("❌ Failed to schedule background task (main thread): \(error)", log: Logger.background)
                }
            }
            return
        }
        
        // Create request safely
        let request = BGAppRefreshTaskRequest(identifier: self.taskIdentifier)
        let earliestBeginDate = safeEarliestBeginDate()
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.info("✅ Background task scheduled for: \(earliestBeginDate)", log: Logger.background)
            
            // Log all pending task requests for debugging
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                Logger.info("Pending task requests: \(requests.count)", log: Logger.background)
                for (index, request) in requests.enumerated() {
                    Logger.info("Task \(index + 1): ID=\(request.identifier), earliestBeginDate=\(String(describing: request.earliestBeginDate))", log: Logger.background)
                }
            }
            
        } catch {
            Logger.error("❌ Failed to schedule background task: \(error)", log: Logger.background)
            throw BackgroundTaskServiceError.schedulingFailed
        }
        #endif
    }
    
    func handleSendReportTask(_ task: BGAppRefreshTask) async {
        Logger.info("Handling send report background task", log: Logger.background)
        
        // Создаем операционную очередь для управления задачами
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        // Устанавливаем обработчик завершения задачи
        task.expirationHandler = {
            Logger.warning("Background task expired, cancelling operations", log: Logger.background)
            operationQueue.cancelAllOperations()
            task.setTaskCompleted(success: false)
        }
        
        // Планируем следующую задачу СРАЗУ (до выполнения текущей)
        do {
            try self.scheduleSendReportTask()
            Logger.info("Next background task scheduled", log: Logger.background)
        } catch {
            Logger.error("Failed to schedule next background task: \(error)", log: Logger.background)
        }
        
        // Выполняем работу в операционной очереди
        operationQueue.addOperation { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                guard let self = self else { return }
                // Проверяем настройки автоотправки через AutoSendService
                if self.autoSendService.autoSendEnabled {
                    Logger.info("Auto-send enabled, processing reports", log: Logger.background)
                    await self.processAutoSendReports()
                } else {
                    Logger.info("Auto-send disabled, skipping", log: Logger.background)
                }
                
                // Завершаем задачу успешно
                task.setTaskCompleted(success: true)
                Logger.info("Background task completed successfully", log: Logger.background)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func safeEarliestBeginDate() -> Date {
        let computed = calculateEarliestBeginDate()
        // iOS требует минимум 15 минут, но лучше дать больше времени
        let minDate = Date().addingTimeInterval(15 * 60)
        return max(computed, minDate)
    }
    
    private func calculateEarliestBeginDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Получаем время автоотправки из AutoSendService
        let autoSendTime = autoSendService.autoSendTime
        let targetHour = calendar.component(.hour, from: autoSendTime)
        let targetMinute = calendar.component(.minute, from: autoSendTime)
        
        // Планируем на целевое время сегодня или завтра
        let todayTarget = calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: now)!
        let todayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)!
        
        var earliest: Date
        
        if now < todayTarget {
            // Если сейчас раньше целевого времени, планируем на целевое время сегодня
            earliest = todayTarget
        } else if now >= todayTarget && now <= todayEnd {
            // Если сейчас в промежутке целевого времени - конец дня, планируем на завтра
            let tomorrowTarget = calendar.date(byAdding: .day, value: 1, to: todayTarget)!
            earliest = tomorrowTarget
        } else {
            // Если сейчас после конца дня, планируем на целевое время завтра
            let tomorrowTarget = calendar.date(byAdding: .day, value: 1, to: todayTarget)!
            earliest = tomorrowTarget
        }
        
        Logger.info("Calculated earliest begin date: \(earliest) (target time: \(targetHour):\(String(format: "%02d", targetMinute)))", log: Logger.background)
        return earliest
    }
    
    private func processAutoSendReports() async {
        Logger.info("Processing auto-send reports", log: Logger.background)
        
        // Check if auto-send is still enabled before proceeding
        guard self.autoSendService.autoSendEnabled else {
            Logger.info("Auto-send is disabled, skipping report sending", log: Logger.background)
            return
        }
        
        // Use AutoSendService to send reports
        Logger.info("Initiating auto-send via AutoSendService", log: Logger.background)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.autoSendService.performAutoSendReport {
                continuation.resume()
            }
        }
        
        // После попытки отправки за сегодня — отправляем неотправленные отчёты за прошлые дни
        if let postTelegramService = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self) {
            Logger.info("Triggering send of unsent reports from previous days", log: Logger.background)
            postTelegramService.sendUnsentReportsFromPreviousDays()
        } else {
            Logger.warning("PostTelegramService not available; cannot send previous days reports", log: Logger.background)
        }
        
        // Log completion
        Logger.info("Auto-send reports processing completed", log: Logger.background)
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
    
    /// Получить информацию о pending задачах (для отладки)
    func getPendingTasksInfo() async -> String {
        return await withCheckedContinuation { continuation in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                let info = requests.map { request in
                    "ID: \(request.identifier), earliestBeginDate: \(request.earliestBeginDate?.description ?? "nil")"
                }.joined(separator: "; ")
                continuation.resume(returning: "Pending tasks (\(requests.count)): \(info)")
            }
        }
    }
    
    #if DEBUG
    /// Тестирование background task (только для отладки)
    func testBackgroundTask() {
        Logger.info("Testing background task execution", log: Logger.background)
        
        // В DEBUG режиме просто вызываем логику автоотправки напрямую
        Task {
            await processAutoSendReports()
        }
    }
    #endif
}

