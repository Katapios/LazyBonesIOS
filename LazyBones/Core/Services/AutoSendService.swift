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
        autoSendTimer?.invalidate()
        guard autoSendEnabled else { 
            print("[AutoSend] Disabled")
            return 
        }
        
        // Планируем фоновую задачу через BackgroundTaskService
        do {
            let backgroundTaskService = DependencyContainer.shared.resolve(BackgroundTaskServiceProtocol.self)!
            try backgroundTaskService.scheduleSendReportTask()
            print("[AutoSend] Background task scheduled")
        } catch {
            print("[AutoSend] Failed to schedule background task: \(error)")
        }
        
        // Для отладки используем Timer в DEBUG режиме
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
        print("[AutoSend] DEBUG: Scheduling timer for", todaySend, "in", interval, "seconds")
        
        if interval > 0 {
            autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.performAutoSendReport()
            }
        }
        #endif
    }
    
    func performAutoSendReport() {
        postTelegramService.performAutoSendReport {
            // Обновляем статус после отправки
            DispatchQueue.main.async {
                // Обновляем статус через PostStore если он доступен
                if let postStore = DependencyContainer.shared.resolve(PostsProviderProtocol.self) as? PostStore {
                    postStore.updateReportStatus()
                    print("[DEBUG] Автоотправка: статус обновлен через updateReportStatus()")
                }
                
                WidgetCenter.shared.reloadAllTimelines()
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