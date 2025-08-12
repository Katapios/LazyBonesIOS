import Foundation
import AVFoundation
import WidgetKit
import UserNotifications
import BackgroundTasks // Added for BGTaskScheduler
import ObjectiveC
import Combine

// Импорт для использования Domain entities
// Убираем @_exported импорты, так как они вызывают ошибки компиляции



// Импорт для использования ReportStatus из нового модуля

/// Модель отчёта пользователя
struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    var goodItems: [String]
    var badItems: [String]
    var published: Bool
    var voiceNotes: [VoiceNote] // Массив голосовых заметок
    var type: PostType // Тип отчета: обычный, кастомный (план/теги)
    var isEvaluated: Bool? // true, если отчет оценен (только для кастомных)
    var evaluationResults: [Bool]? // массив булевых значений для итоговой оценки кастомного отчета
    // --- Telegram integration fields ---
    var authorUsername: String? // username автора из Telegram
    var authorFirstName: String? // имя автора из Telegram
    var authorLastName: String? // фамилия автора из Telegram
    var isExternal: Bool? // true, если отчет из Telegram
    var externalVoiceNoteURLs: [URL]? // ссылки на голосовые заметки из Telegram
    var externalText: String? // полный текст сообщения из Telegram с разметкой
    var externalMessageId: Int? // message_id из Telegram
    var authorId: Int? // ID автора сообщения из Telegram
}

// MARK: - Импорт Domain Entities
// PostType, ReportStatus, NotificationMode теперь определены в Domain/Entities/

/// Протокол хранилища отчётов
protocol PostStoreProtocol: ObservableObject {
    var posts: [Post] { get set }
    func load()
    func save()
    func add(post: Post)
    func clear()
    func getDeviceName() -> String
}

/// Хранилище отчётов с поддержкой App Group
class PostStore: ObservableObject, PostStoreProtocol {
    static let shared = PostStore()
    static let appGroup = AppConfig.appGroup
    @Published var posts: [Post] = []
    @Published var externalPosts: [Post] = [] // Внешние отчеты из Telegram
    @Published var telegramToken: String? = nil
    @Published var telegramChatId: String? = nil
    @Published var telegramBotId: String? = nil
    @Published var lastUpdateId: Int? = nil
    // ОБРАТНАЯ СОВМЕСТИМОСТЬ: Публичные свойства для статусной модели
    var reportStatus: ReportStatus {
        get { return statusManager.reportStatus }
        set { /* Делегируем к statusManager */ }
    }
    
    // Пересоздаёт Telegram сервисы после изменения токена в DI
    func refreshTelegramServices() {
        Logger.info("Refreshing Telegram services in PostStore", log: Logger.general)
        if let newPostTelegramService = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self) {
            self.telegramService = newPostTelegramService
        } else {
            // На случай, если DI ещё не готов — создадим с текущим токеном из UserDefaults
            let token = UserDefaultsManager.shared.string(forKey: "telegramToken") ?? ""
            let telegramService = TelegramService(token: token)
            self.telegramService = PostTelegramService(
                telegramService: telegramService,
                userDefaultsManager: UserDefaultsManager.shared
            )
        }
        // Синхронизируем Published-поля для легаси UI
        DispatchQueue.main.async {
            self.loadTelegramSettings()
            self.objectWillChange.send()
        }
    }
    var forceUnlock: Bool {
        get { return statusManager.forceUnlock }
        set { statusManager.forceUnlock = newValue }
    }
    @Published var timeLeft: String = "" // Новое свойство для отображения таймера
    var currentDay: Date {
        get { return statusManager.currentDay }
        set { /* Делегируем к statusManager */ }
    }
    
    // Сервисы
    private var telegramService: PostTelegramServiceProtocol
    private let notificationService: PostNotificationServiceProtocol
    private lazy var timerService: PostTimerServiceProtocol = {
        return PostTimerService(
            userDefaultsManager: userDefaultsManager
        ) { [weak self] timeLeft, progress in
            DispatchQueue.main.async {
                self?.timeLeft = timeLeft
            }
        }
    }()
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let localService: LocalReportService
    
    // НОВОЕ: ReportStatusManager для управления статусной моделью
    private lazy var statusManager: any ReportStatusManagerProtocol = {
        return ReportStatusManager(
            localService: localService,
            timerService: timerService,
            notificationService: notificationService,
            postsProvider: self,
            factory: ReportStatusFactory()
        )
    }()
    
    // TelegramService для получения обновлений
    private var telegramServiceForUpdates: TelegramServiceProtocol? {
        return DependencyContainer.shared.resolve(TelegramServiceProtocol.self)
    }
    
    // НОВОЕ: TelegramIntegrationService для управления Telegram интеграцией
    private(set) var telegramIntegrationService: TelegramIntegrationServiceType!
    // НОВОЕ: NotificationManagerService для управления уведомлениями
    private(set) var notificationManagerService: NotificationManagerServiceType
    
    // НОВОЕ: AutoSendService для управления автоотправкой
    private(set) var autoSendService: AutoSendServiceType
    
    // Для хранения подписок
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFromNotificationService = false
    private var statusChangeObserver: NSObjectProtocol?
    
    init() {
        print("[DEBUG][INIT] PostStore инициализирован")
        
        // Получаем сервисы из DI контейнера безопасно
        guard let userDefaultsManager = DependencyContainer.shared.resolve(UserDefaultsManager.self),
              let telegramService = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self),
              let notificationService = DependencyContainer.shared.resolve(PostNotificationServiceProtocol.self),
              let notificationManagerService = DependencyContainer.shared.resolve(NotificationManagerServiceType.self),
              let telegramIntegrationService = DependencyContainer.shared.resolve(TelegramIntegrationServiceType.self),
              let autoSendService = DependencyContainer.shared.resolve(AutoSendServiceType.self) else {
            Logger.critical("Failed to resolve required dependencies in PostStore init", log: Logger.general)
            // Используем дефолтные значения вместо краша
            self.userDefaultsManager = UserDefaultsManager.shared
            self.telegramService = PostTelegramService(telegramService: TelegramService(token: ""), userDefaultsManager: UserDefaultsManager.shared)
            self.notificationService = PostNotificationService(notificationService: NotificationService(), userDefaultsManager: UserDefaultsManager.shared)
            self.notificationManagerService = NotificationManagerService(userDefaultsManager: UserDefaultsManager.shared, notificationService: NotificationService())
            self.telegramIntegrationService = TelegramIntegrationService(userDefaultsManager: UserDefaultsManager.shared, telegramService: nil)
            self.autoSendService = AutoSendService(userDefaultsManager: UserDefaultsManager.shared, postTelegramService: PostTelegramService(telegramService: TelegramService(token: ""), userDefaultsManager: UserDefaultsManager.shared))
            self.localService = LocalReportService.shared
            self.statusManager = ReportStatusManager(
                localService: LocalReportService.shared,
                timerService: PostTimerService(userDefaultsManager: UserDefaultsManager.shared) { _, _ in },
                notificationService: PostNotificationService(notificationService: NotificationService(), userDefaultsManager: UserDefaultsManager.shared),
                postsProvider: self
            )
            return
        }
        
        self.userDefaultsManager = userDefaultsManager
        self.telegramService = telegramService
        self.notificationService = notificationService
        self.localService = LocalReportService.shared
        self.notificationManagerService = notificationManagerService
        self.telegramIntegrationService = telegramIntegrationService
        self.autoSendService = autoSendService
        
        // Инициализируем statusManager
        self.statusManager = ReportStatusManager(
            localService: LocalReportService.shared,
            timerService: timerService,
            notificationService: notificationService,
            postsProvider: self
        )
        
        // TelegramService для получения обновлений берется через computed property
        // self.telegramServiceForUpdates = DependencyContainer.shared.resolve(TelegramServiceProtocol.self)
        
        // НОВОЕ: TelegramIntegrationService для управления Telegram интеграцией
        self.telegramIntegrationService = telegramIntegrationService
        
        // НОВОЕ: NotificationManagerService для управления уведомлениями
        self.notificationManagerService = notificationManagerService
        
        // НОВОЕ: AutoSendService для управления автоотправкой
        self.autoSendService = autoSendService
        
        // Для хранения подписок
        self.cancellables = Set<AnyCancellable>()
        self.isUpdatingFromNotificationService = false
        
        // Подписка: изменения статуса отчета -> перерисовать все вью, зависящие от PostStore
        statusChangeObserver = NotificationCenter.default.addObserver(
            forName: .reportStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Синхронизируем локальный statusManager и уведомляем SwiftUI на следующем тике,
            // чтобы не публиковать изменения во время обновления вью
            DispatchQueue.main.async {
                self?.statusManager.loadStatus()
                self?.objectWillChange.send()
            }
        }
        
        loadSettings()
        loadTelegramSettings()
        
        // Синхронизируем внешние отчеты с новым сервисом
        externalPosts = telegramIntegrationService.externalPosts
        
        // Инициализируем таймер и другие компоненты после полной инициализации
        updateTimeLeft()
        startTimer()
        loadGoodTags()
        loadBadTags()
        // Автоотправка теперь управляется через AutoSendService
        autoSendService.loadAutoSendSettings()
        autoSendService.scheduleAutoSendIfNeeded()
        
        // Инициализируем уведомления при запуске
        if notificationsEnabled {
            notificationManagerService.requestNotificationPermissionAndSchedule()
        }
        
        print("[DEBUG][INIT] PostStore инициализация завершена")
    }
    
    private func loadSettings() {
        load()
        loadNotificationSettings()
        // Автоотправка теперь управляется через AutoSendService
        loadTags()
    }
        // --- Notification settings ---
    @Published var notificationsEnabled: Bool = false {
        didSet {
            if !isUpdatingFromNotificationService {
                // Синхронизируем с NotificationManagerService
                notificationManagerService.notificationsEnabled = notificationsEnabled
            }
        }
    }
    @Published var notificationIntervalHours: Int = 1 { // 1-12
        didSet {
            if !isUpdatingFromNotificationService {
                notificationManagerService.notificationIntervalHours = notificationIntervalHours
            }
        }
    }
    @Published var notificationStartHour: Int = 8 { // В будущем можно сделать настраиваемым
        didSet {
            if !isUpdatingFromNotificationService {
                notificationManagerService.notificationStartHour = notificationStartHour
            }
        }
    }
    @Published var notificationEndHour: Int = 22 { // В будущем можно сделать настраиваемым
        didSet {
            if !isUpdatingFromNotificationService {
                notificationManagerService.notificationEndHour = notificationEndHour
            }
        }
    }
    @Published var notificationMode: NotificationMode = .hourly {
        didSet {
            if !isUpdatingFromNotificationService {
                notificationManagerService.notificationMode = notificationMode
            }
        }
    }
    @Published var goodTags: [String] = []
    @Published var badTags: [String] = []
    // --- Автоотправка управляется через AutoSendService ---



    deinit {
        if let token = statusChangeObserver {
            NotificationCenter.default.removeObserver(token)
        }
        stopTimer()
    }

    /// Загрузка отчётов из LocalReportService
    func load() {
        print("[DEBUG][PostStore] load() called")
        posts = localService.loadPosts()
        print("[DEBUG][PostStore] loaded posts count: \(posts.count)")
    }
    /// Сохранение отчётов через LocalReportService
    func save() {
        print("[DEBUG][PostStore] save() called, posts count: \(posts.count)")
        localService.savePosts(posts)
    }
    /// Добавление нового отчёта
    func add(post: Post) {
        print("[DEBUG][PostStore] add(post:) called")
        posts.append(post)
        save()
        autoSendService.scheduleAutoSendIfNeeded()
        let today = Calendar.current.startOfDay(for: Date())
        if forceUnlock && Calendar.current.isDate(post.date, inSameDayAs: today) {
            forceUnlock = false
            localService.saveForceUnlock(false)
        }
        updateReportStatus()
        WidgetCenter.shared.reloadAllTimelines()
        print("[DEBUG][PostStore] add: published=\(post.published), forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
    }
    /// Очистка всех отчётов
    func clear() {
        print("[DEBUG][PostStore] clear() called")
        posts = []
        localService.clearPosts()
        updateReportStatus()
        WidgetCenter.shared.reloadAllTimelines()
    }
    /// Обновление существующего отчёта по id
    func update(post: Post) {
        print("[DEBUG][PostStore] update(post:) called")
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
            save()
            autoSendService.scheduleAutoSendIfNeeded()
            let today = Calendar.current.startOfDay(for: Date())
            if forceUnlock && Calendar.current.isDate(post.date, inSameDayAs: today) {
                forceUnlock = false
                localService.saveForceUnlock(false)
            }
            updateReportStatus()
            WidgetCenter.shared.reloadAllTimelines()
            print("[DEBUG][PostStore] update: published=\(post.published), forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
        }
    }
    func getDeviceName() -> String {
        // Можно вынести в отдельный сервис при необходимости
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        return userDefaults?.string(forKey: "deviceName") ?? "Устройство"
    }
    // MARK: - Telegram Integration
    func setTelegramService() {
        // Этот метод больше не нужен, так как мы используем DI контейнер
        // TelegramService создается через DependencyContainer
        Logger.debug("setTelegramService called - using DI container", log: Logger.general)
    }
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        
        // Обновляем локальные свойства для обратной совместимости
        telegramToken = token
        telegramChatId = chatId
        telegramBotId = botId
    }
    func loadTelegramSettings() {
        // Делегируем к telegramIntegrationService
        let settings = telegramIntegrationService.loadTelegramSettings()
        
        // Обновляем локальные свойства для обратной совместимости
        telegramToken = settings.token
        telegramChatId = settings.chatId
        telegramBotId = settings.botId
        lastUpdateId = telegramIntegrationService.lastUpdateId
    }
    func saveLastUpdateId(_ updateId: Int) {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.saveLastUpdateId(updateId)
        
        // Обновляем локальное свойство для обратной совместимости
        lastUpdateId = updateId
    }
    // Загрузка внешних отчетов из Telegram
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.fetchExternalPosts { [weak self] success in
            if success {
                // Обновляем локальное свойство для обратной совместимости
                self?.externalPosts = self?.telegramIntegrationService.externalPosts ?? []
            }
            completion(success)
        }
    }
    func saveExternalPosts() {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.saveExternalPosts()
    }
    
    func loadExternalPosts() {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.loadExternalPosts()
        
        // Обновляем локальное свойство для обратной совместимости
        externalPosts = telegramIntegrationService.externalPosts
    }
    func deleteBotMessages(completion: @escaping (Bool) -> Void) {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.deleteBotMessages(completion: completion)
    }
    
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        // Делегируем к telegramIntegrationService
        telegramIntegrationService.deleteAllBotMessages(completion: completion)
    }
    // MARK: - Report Status (ОБРАТНАЯ СОВМЕСТИМОСТЬ)
    func updateReportStatus() {
        // Делегируем к statusManager
        statusManager.updateStatus()
    }
    func loadReportStatus() {
        // Делегируем к statusManager
        statusManager.loadStatus()
    }
    /// Разблокировать возможность создания отчёта (не трогая локальные отчёты)
    func unlockReportCreation() {
        // Делегируем к statusManager
        statusManager.unlockReportCreation()
    }
    
    func checkForNewDay() {
        // Делегируем к statusManager
        statusManager.checkForNewDay()
    }
    
    // УДАЛЕНО: loadForceUnlock() - теперь делегируется к statusManager
    // Объединить локальные и внешние отчеты для отображения
    var allPosts: [Post] {
        // Делегируем к telegramIntegrationService
        return telegramIntegrationService.getAllPosts()
    }
}

// MARK: - PostsProviderProtocol Extension
extension PostStore: PostsProviderProtocol {
    func getPosts() -> [Post] {
        return posts
    }
    
    func updatePosts(_ posts: [Post]) {
        self.posts = posts
        save()
    }
}

// MARK: - Notification Settings
extension PostStore {
    // УДАЛЕНО: константы ключей теперь используются в NotificationManagerService
    
    func saveNotificationSettings() {
        // Делегируем к notificationManagerService
        notificationManagerService.saveNotificationSettings()
    }
    
    func loadNotificationSettings() {
        // Делегируем к notificationManagerService
        notificationManagerService.loadNotificationSettings()
        
        // Синхронизируем локальные свойства для обратной совместимости
        notificationsEnabled = notificationManagerService.notificationsEnabled
        notificationMode = notificationManagerService.notificationMode
        notificationIntervalHours = notificationManagerService.notificationIntervalHours
        notificationStartHour = notificationManagerService.notificationStartHour
        notificationEndHour = notificationManagerService.notificationEndHour
    }
}

// MARK: - Notification Logic
extension PostStore {
    func requestNotificationPermissionAndSchedule() {
        // Делегируем к notificationManagerService
        notificationManagerService.requestNotificationPermissionAndSchedule()
    }
    
    func scheduleNotifications() {
        // Делегируем к notificationManagerService
        notificationManagerService.scheduleNotifications()
    }
    
    func cancelAllNotifications() {
        // Делегируем к notificationManagerService
        notificationManagerService.cancelAllNotifications()
    }
    
    func timeLeftString(untilHour: Int) -> String {
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(bySettingHour: untilHour, minute: 0, second: 0, of: now) ?? now
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: end)
        let h = max(0, diff.hour ?? 0)
        let m = max(0, diff.minute ?? 0)
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Timer Logic
extension PostStore {
    /// Таймер
    func startTimer() {
        timerService.startTimer()
    }
    
    func stopTimer() {
        timerService.stopTimer()
    }
    
    func updateTimeLeft() {
        // Обновляем статус в таймер-сервисе
        timerService.updateReportStatus(reportStatus)
        timerService.updateTimeLeft()
        
        // Проверяем, не наступил ли новый день
        checkForNewDay()
        
        // Обновляем статус отчета при необходимости
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let hasTodayPost = posts.contains(where: { calendar.isDate($0.date, inSameDayAs: today) })
        if !hasTodayPost && reportStatus != .notStarted {
            updateReportStatus()
        }
    }
    
    // УДАЛЕНО: checkForNewDay() - теперь делегируется к statusManager
    
    /// Проверяет, активен ли период для создания/редактирования отчетов
    func isReportPeriodActive() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(
            bySettingHour: notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        return now >= start && now < end
    }
    // MARK: - Good/Bad Tags
    func loadTags() {
        loadGoodTags()
        loadBadTags()
    }
    
    func loadGoodTags() {
        self.goodTags = localService.loadGoodTags()
    }
    func saveGoodTags(_ tags: [String]) {
        localService.saveGoodTags(tags)
        self.goodTags = tags
    }
    func addGoodTag(_ tag: String) {
        localService.addGoodTag(tag)
        self.goodTags = localService.loadGoodTags()
        Logger.info("Added good tag: \(tag)", log: Logger.general)
    }
    func removeGoodTag(_ tag: String) {
        localService.removeGoodTag(tag)
        self.goodTags = localService.loadGoodTags()
        Logger.info("Removed good tag: \(tag)", log: Logger.general)
    }
    func updateGoodTag(old: String, new: String) {
        localService.updateGoodTag(old: old, new: new)
        self.goodTags = localService.loadGoodTags()
        Logger.info("Updated good tag: \(old) -> \(new)", log: Logger.general)
    }
    func loadBadTags() {
        self.badTags = localService.loadBadTags()
    }
    func saveBadTags(_ tags: [String]) {
        localService.saveBadTags(tags)
        self.badTags = tags
    }
    func addBadTag(_ tag: String) {
        localService.addBadTag(tag)
        self.badTags = localService.loadBadTags()
        Logger.info("Added bad tag: \(tag)", log: Logger.general)
    }
    func removeBadTag(_ tag: String) {
        localService.removeBadTag(tag)
        self.badTags = localService.loadBadTags()
        Logger.info("Removed bad tag: \(tag)", log: Logger.general)
    }
    func updateBadTag(old: String, new: String) {
        localService.updateBadTag(old: old, new: new)
        self.badTags = localService.loadBadTags()
        Logger.info("Updated bad tag: \(old) -> \(new)", log: Logger.general)
    }

    // MARK: - Автоотправка в Telegram (делегируется к AutoSendService)
    /// Автоматическая отправка всех отчетов за сегодня (кастомный и обычный)
    func autoSendAllReportsForToday(completion: (() -> Void)? = nil) {
        autoSendService.autoSendAllReportsForToday(completion: completion)
    }
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        telegramService.sendToTelegram(text: text, completion: completion)
    }
    
    // MARK: - Telegram Message Conversion
    
    /// Преобразует сообщение Telegram в объект Post
    private func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? {
        // Делегируем к telegramIntegrationService
        return telegramIntegrationService.convertTelegramMessageToPost(message)
    }
}

extension PostStore {
    static func rescheduleBGTask() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.backgroundTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BGTask] Не удалось запланировать задачу: \(error)")
        }
    }
}

// Вспомогательная структура для миграции
private struct LegacyPost: Codable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
    let voiceNoteURL: String?
} 