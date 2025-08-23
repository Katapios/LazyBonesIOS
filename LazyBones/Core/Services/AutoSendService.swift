import Foundation
import Combine
import ObjectiveC
import WidgetKit
import BackgroundTasks

/// Протокол для сервиса автоотправки
protocol AutoSendServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    var autoSendEnabled: Bool { get set }
    var autoSendTime: Date { get set }
    var lastAutoSendStatus: String? { get set }
    
    // MARK: - Auto Send Management
    func loadAutoSendSettings()
    func saveAutoSendSettings()
    func scheduleAutoSendIfNeeded()
    func performAutoSendReport()
    func performAutoSendReport(completion: (() -> Void)?)
    func autoSendAllReportsForToday(completion: (() -> Void)?)
}

/// Сервис для управления автоотправкой отчётов
class AutoSendService: AutoSendServiceProtocol {
    
    // MARK: - Published Properties
    @Published var autoSendEnabled: Bool = false {
        didSet {
            if !isLoadingSettings {
                saveAutoSendSettings()
                if autoSendEnabled {
                    // Планируем фоновые задачи/таймеры
                    scheduleAutoSendIfNeeded()
                } else {
                    // Отменяем таймер
                    autoSendTimer?.invalidate()
                    autoSendTimer = nil
                    // Отменяем все BG задачи, чтобы не запускались после отключения
                    BGTaskScheduler.shared.cancelAllTaskRequests()
                    Logger.info("Auto-send disabled: cancelled all BG task requests", log: Logger.background)
                }
            }
        }
    }
    
    @Published var autoSendTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            if !isLoadingSettings {
                saveAutoSendSettings()
                scheduleAutoSendIfNeeded()
            }
        }
    }
    
    @Published var lastAutoSendStatus: String? = nil {
        didSet {
            if !isLoadingSettings {
                saveAutoSendSettings()
            }
        }
    }
    
    // MARK: - Dependencies
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let postTelegramService: PostTelegramServiceProtocol
    private let loadAutoSendSettingsUC: LoadAutoSendSettingsUseCase
    private let saveAutoSendSettingsUC: SaveAutoSendSettingsUseCase
    
    // MARK: - Private Properties
    private var isLoadingSettings = false
    private var autoSendTimer: Timer? {
        get { objc_getAssociatedObject(self, &AutoSendService.autoSendTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &AutoSendService.autoSendTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var autoSendTimerKey: UInt8 = 0
    private var isRunningTests: Bool { NSClassFromString("XCTestCase") != nil }
    
    private var lastAutoSendDate: Date? {
        get {
            return userDefaultsManager.get(Date.self, forKey: "lastAutoSendDate")
        }
        set {
            userDefaultsManager.set(newValue, forKey: "lastAutoSendDate")
        }
    }
    
    // MARK: - Initialization
    init(
        userDefaultsManager: UserDefaultsManagerProtocol,
        postTelegramService: PostTelegramServiceProtocol
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.postTelegramService = postTelegramService
        // CA wiring (internal): build repository and use cases using provided dependencies
        let repo = AutoSendSettingsRepositoryImpl(userDefaults: userDefaultsManager)
        self.loadAutoSendSettingsUC = LoadAutoSendSettingsUseCaseImpl(repository: repo)
        self.saveAutoSendSettingsUC = SaveAutoSendSettingsUseCaseImpl(repository: repo)
        
        loadAutoSendSettings()
    }
    
    // MARK: - AutoSendServiceProtocol
    
    func loadAutoSendSettings() {
        isLoadingSettings = true
        let settings = loadAutoSendSettingsUC.execute()
        autoSendEnabled = settings.enabled
        autoSendTime = settings.time
        lastAutoSendStatus = settings.lastStatus
        // lastAutoSendDate already backed by UD; we can leave it as is or mirror settings.lastDate if needed
        isLoadingSettings = false
    }
    
    func saveAutoSendSettings() {
        let settings = AutoSendSettings(
            enabled: autoSendEnabled,
            time: autoSendTime,
            lastStatus: lastAutoSendStatus,
            lastDate: lastAutoSendDate
        )
        saveAutoSendSettingsUC.execute(settings)
        print("[AutoSend][SAVE] Сохраняю время автоотправки: \(autoSendTime)")
        // Обновляем виджет при изменении настроек автоотправки
        if !isRunningTests {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            Logger.debug("[AutoSend][Tests] Skip WidgetCenter.reloadAllTimelines()", log: Logger.background)
        }
    }
    
    func scheduleAutoSendIfNeeded() {
        Logger.info("Scheduling auto-send if needed", log: Logger.background)
        
        // Invalidate any existing timer
        autoSendTimer?.invalidate()
        
        guard autoSendEnabled else { 
            Logger.info("Auto-send is disabled, skipping scheduling", log: Logger.background)
            return 
        }
        
        // Skip background scheduling and timers in tests to avoid simulator issues
        if isRunningTests {
            Logger.info("[AutoSend][Tests] Skipping background scheduling and timers", log: Logger.background)
            return
        }
        
        // Schedule the background task (optional DI)
        do {
            if let backgroundTaskService = DependencyContainer.shared.resolve(BackgroundTaskServiceProtocol.self) {
                try backgroundTaskService.scheduleSendReportTask()
                Logger.info("✅ Background task scheduled successfully", log: Logger.background)
            } else {
                Logger.warning("[AutoSend] BackgroundTaskService is not registered in DI. Skipping BG scheduling.", log: Logger.background)
            }
        } catch {
            Logger.error("❌ Failed to schedule background task: \(error)", log: Logger.background)
            
            // Try to recover by rescheduling after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                Logger.info("Retrying background task scheduling after error", log: Logger.background)
                self?.scheduleAutoSendIfNeeded()
            }
        }
        
        // For debugging in DEBUG mode, use a Timer
        #if DEBUG
        let now = Date()
        let cal = Calendar.current
        let todaySend = cal.date(
            bySettingHour: cal.component(.hour, from: autoSendTime),
            minute: cal.component(.minute, from: autoSendTime),
            second: 0,
            of: now
        ) ?? autoSendTime
        
        let interval = todaySend.timeIntervalSince(now)
        Logger.info("DEBUG: Scheduling timer for \(todaySend) in \(interval) seconds", log: Logger.background)
        
        if interval > 0 {
            autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Logger.info("DEBUG: Timer fired, performing auto-send", log: Logger.background)
                self?.performAutoSendReport()
            }
        } else {
            Logger.info("DEBUG: Not scheduling timer as interval is negative: \(interval)", log: Logger.background)
        }
        #endif
    }
    
    func performAutoSendReport() {
        performAutoSendReport(completion: nil)
    }
    
    func performAutoSendReport(completion: (() -> Void)? = nil) {
        Logger.info("Starting auto-send report process", log: Logger.background)
        
        // Update last auto-send status
        lastAutoSendStatus = "Sending..."
        lastAutoSendDate = Date()
        
        postTelegramService.performAutoSendReport { [weak self] in
            guard let self = self else { return }
            
            // Update status after sending
            DispatchQueue.main.async {
                Logger.info("Auto-send report completed, updating UI", log: Logger.background)
                
                // Update status via PostStore if available
                if let postStore = DependencyContainer.shared.resolve(PostsProviderProtocol.self) as? PostStore {
                    postStore.updateReportStatus()
                    Logger.info("Report status updated via PostStore", log: Logger.background)
                } else {
                    Logger.warning("PostStore not available for status update", log: Logger.background)
                }
                
                // Update last status and save
                self.lastAutoSendStatus = "Last sent: \(Date().formatted())"
                self.saveAutoSendSettings()
                
                // Reload widgets
                if !self.isRunningTests {
                    WidgetCenter.shared.reloadAllTimelines()
                } else {
                    Logger.debug("[AutoSend][Tests] Skip WidgetCenter.reloadAllTimelines() after send", log: Logger.background)
                }
                
                // Reschedule the next auto-send
                if !self.isRunningTests {
                    self.scheduleAutoSendIfNeeded()
                } else {
                    Logger.debug("[AutoSend][Tests] Skip rescheduling after send", log: Logger.background)
                }
                
                Logger.info("Auto-send process completed successfully", log: Logger.background)
                
                // Notify external completion if provided (for BG task coordination)
                completion?()
            }
        }
    }
    
    func autoSendAllReportsForToday(completion: (() -> Void)? = nil) {
        postTelegramService.autoSendAllReportsForToday()
        completion?()
    }
}

// MARK: - Typealias for easier usage
typealias AutoSendServiceType = any AutoSendServiceProtocol 
