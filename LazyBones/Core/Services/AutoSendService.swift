import Foundation
import Combine
import ObjectiveC
import WidgetKit

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
    func autoSendAllReportsForToday(completion: (() -> Void)?)
}

/// Сервис для управления автоотправкой отчётов
class AutoSendService: AutoSendServiceProtocol {
    
    // MARK: - Published Properties
    @Published var autoSendEnabled: Bool = false {
        didSet {
            if !isLoadingSettings {
                saveAutoSendSettings()
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
    
    // MARK: - Private Properties
    private var isLoadingSettings = false
    private var autoSendTimer: Timer? {
        get { objc_getAssociatedObject(self, &AutoSendService.autoSendTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &AutoSendService.autoSendTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var autoSendTimerKey: UInt8 = 0
    
    private var lastAutoSendDate: Date? {
        get {
            let ud = UserDefaults(suiteName: PostStore.appGroup)
            return ud?.object(forKey: "lastAutoSendDate") as? Date
        }
        set {
            let ud = UserDefaults(suiteName: PostStore.appGroup)
            ud?.set(newValue, forKey: "lastAutoSendDate")
        }
    }
    
    // MARK: - Initialization
    init(
        userDefaultsManager: UserDefaultsManagerProtocol,
        postTelegramService: PostTelegramServiceProtocol
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.postTelegramService = postTelegramService
        
        loadAutoSendSettings()
    }
    
    // MARK: - AutoSendServiceProtocol
    
    func loadAutoSendSettings() {
        isLoadingSettings = true
        
        let userDefaults = UserDefaults(suiteName: PostStore.appGroup)
        autoSendEnabled = userDefaults?.bool(forKey: "autoSendToTelegram") ?? false
        
        if let date = userDefaults?.object(forKey: "autoSendTime") as? Date {
            print("[AutoSend][LOAD] Загружено время автоотправки: \(date)")
            autoSendTime = date
        } else {
            print("[AutoSend][LOAD] Время автоотправки не найдено, используется дефолт: \(autoSendTime)")
        }
        
        lastAutoSendStatus = userDefaults?.string(forKey: "lastAutoSendStatus")
        
        isLoadingSettings = false
    }
    
    func saveAutoSendSettings() {
        let userDefaults = UserDefaults(suiteName: PostStore.appGroup)
        userDefaults?.set(autoSendEnabled, forKey: "autoSendToTelegram")
        userDefaults?.set(autoSendTime, forKey: "autoSendTime")
        userDefaults?.set(lastAutoSendStatus, forKey: "lastAutoSendStatus")
        print("[AutoSend][SAVE] Сохраняю время автоотправки: \(autoSendTime)")
        
        // Обновляем виджет при изменении настроек автоотправки
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func scheduleAutoSendIfNeeded() {
        Logger.info("Scheduling auto-send if needed", log: Logger.background)
        
        // Invalidate any existing timer
        autoSendTimer?.invalidate()
        
        guard autoSendEnabled else { 
            Logger.info("Auto-send is disabled, skipping scheduling", log: Logger.background)
            return 
        }
        
        // Schedule the background task
        do {
            let backgroundTaskService = DependencyContainer.shared.resolve(BackgroundTaskServiceProtocol.self)!
            try backgroundTaskService.scheduleSendReportTask()
            Logger.info("✅ Background task scheduled successfully", log: Logger.background)
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
                WidgetCenter.shared.reloadAllTimelines()
                
                // Reschedule the next auto-send
                self.scheduleAutoSendIfNeeded()
                
                Logger.info("Auto-send process completed successfully", log: Logger.background)
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
