import Foundation
import AVFoundation
import WidgetKit
import UserNotifications
import BackgroundTasks // Added for BGTaskScheduler
import ObjectiveC



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

/// Тип отчета
enum PostType: String, Codable, CaseIterable {
    case regular // обычный отчет
    case custom // кастомный отчет (план/теги)
    case external // внешний отчет из Telegram
}

// MARK: - Статус отчёта
enum ReportStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case done = "done"
    case notCreated = "notCreated"
    case notSent = "notSent"
    case sent = "sent"
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "Заполни отчет"
        case .inProgress:
            return "Отчет заполняется..."
        case .done:
            return "Завершен"
        case .notCreated:
            return "Отчёт не создан"
        case .notSent:
            return "Отчёт не отправлен"
        case .sent:
            return "Отчет отправлен"
        }
    }
}

// MARK: - Notification Mode
enum NotificationMode: String, Codable, CaseIterable {
    case hourly
    case twice
    var description: String {
        switch self {
        case .hourly: return "Каждый час"
        case .twice: return "2 раза в день"
        }
    }
}

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
    private let telegramService: PostTelegramServiceProtocol
    private let notificationService: PostNotificationServiceProtocol
    private lazy var timerService: PostTimerServiceProtocol = {
        return PostTimerService(
            userDefaultsManager: userDefaultsManager
        ) { [weak self] timeLeft, progress in
            self?.timeLeft = timeLeft
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
    
    init() {
        print("[DEBUG][INIT] PostStore инициализирован")
        
        // Получаем сервисы из DI контейнера
        self.userDefaultsManager = DependencyContainer.shared.resolve(UserDefaultsManager.self)!
        self.telegramService = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self)!
        self.notificationService = DependencyContainer.shared.resolve(PostNotificationServiceProtocol.self)!
        self.localService = LocalReportService.shared
        
        loadSettings()
        loadTelegramSettings()
        loadExternalPosts()
        
        // НОВОЕ: Инициализация statusManager происходит автоматически через lazy var
        // loadReportStatus() - теперь делегируется к statusManager
        // loadForceUnlock() - теперь делегируется к statusManager
        // checkForNewDay() - теперь делегируется к statusManager
        // updateReportStatus() - теперь делегируется к statusManager
        
        updateTimeLeft()
        startTimer()
        loadGoodTags()
        loadBadTags()
        loadAutoSendSettings() // autoSendTime загружается из UserDefaults
        scheduleAutoSendIfNeeded()
    }
    
    private func loadSettings() {
        load()
        loadNotificationSettings()
        loadAutoSendSettings()
        loadTags()
    }
    // --- Notification settings ---
    @Published var notificationsEnabled: Bool = false {
        didSet { saveNotificationSettings();
            if notificationsEnabled { requestNotificationPermissionAndSchedule() } else { cancelAllNotifications() }
        }
    }
    @Published var notificationIntervalHours: Int = 1 { // 1-12
        didSet { saveNotificationSettings(); if notificationsEnabled { scheduleNotifications() } }
    }
    @Published var notificationStartHour: Int = 8 // В будущем можно сделать настраиваемым
    @Published var notificationEndHour: Int = 22 // В будущем можно сделать настраиваемым
    @Published var notificationMode: NotificationMode = .hourly {
        didSet { saveNotificationSettings(); if notificationsEnabled { scheduleNotifications() } }
    }
    @Published var goodTags: [String] = []
    @Published var badTags: [String] = []
    // --- Новое для автоотправки ---
    @Published var autoSendToTelegram: Bool = false {
        didSet {
            saveAutoSendSettings()
        }
    }
    @Published var autoSendTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            saveAutoSendSettings()
            scheduleAutoSendIfNeeded()
        }
    }
    @Published var lastAutoSendStatus: String? = nil {
        didSet {
            saveAutoSendSettings()
        }
    }
    private var lastAutoSendDate: Date? {
        get {
            let ud = UserDefaults(suiteName: Self.appGroup)
            return ud?.object(forKey: "lastAutoSendDate") as? Date
        }
        set {
            let ud = UserDefaults(suiteName: Self.appGroup)
            ud?.set(newValue, forKey: "lastAutoSendDate")
        }
    }



    deinit {
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
        scheduleAutoSendIfNeeded()
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
            scheduleAutoSendIfNeeded()
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
        telegramToken = token
        telegramChatId = chatId
        telegramBotId = botId
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(token, forKey: "telegramToken")
        userDefaults?.set(chatId, forKey: "telegramChatId")
        userDefaults?.set(botId, forKey: "telegramBotId")
        
        // Обновляем TelegramService в DI контейнере
        if let token = token, !token.isEmpty {
            DependencyContainer.shared.registerTelegramService(token: token)
        }
    }
    func loadTelegramSettings() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        telegramToken = userDefaults?.string(forKey: "telegramToken")
        telegramChatId = userDefaults?.string(forKey: "telegramChatId")
        telegramBotId = userDefaults?.string(forKey: "telegramBotId")
        lastUpdateId = userDefaults?.integer(forKey: "lastUpdateId")
        
        // Обновляем TelegramService в DI контейнере если есть токен
        if let token = telegramToken, !token.isEmpty {
            DependencyContainer.shared.registerTelegramService(token: token)
        }
    }
    func saveLastUpdateId(_ updateId: Int) {
        lastUpdateId = updateId
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(updateId, forKey: "lastUpdateId")
    }
    // Загрузка внешних отчетов из Telegram
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        Logger.info("Fetching external posts from Telegram", log: Logger.telegram)
        
        // Проверяем, есть ли настройки Telegram
        guard let token = telegramToken, !token.isEmpty else {
            Logger.error("Telegram token is missing", log: Logger.telegram)
            completion(false)
            return
        }
        
        Task {
            do {
                // Получаем TelegramService для обновлений
                guard let telegramServiceForUpdates = telegramServiceForUpdates else {
                    Logger.error("TelegramService not available", log: Logger.telegram)
                    completion(false)
                    return
                }
                
                // Получаем обновления из Telegram
                let updates = try await telegramServiceForUpdates.getUpdates(offset: lastUpdateId)
                
                // Фильтруем только сообщения (не редактирования)
                let messages = updates.compactMap { update -> TelegramMessage? in
                    if let message = update.message {
                        return message
                    }
                    return nil
                }
                print("[DEBUG] Получено сообщений из Telegram: \(messages.count)")
                for msg in messages {
                    print("[DEBUG] message: \(msg)")
                }
                // Преобразуем сообщения в объекты Post
                var newExternalPosts: [Post] = []
                
                for message in messages {
                    if let post = convertTelegramMessageToPost(message) {
                        newExternalPosts.append(post)
                    }
                }
                
                // Обновляем externalPosts на главном потоке
                let finalExternalPosts = newExternalPosts
                await MainActor.run {
                    self.externalPosts = finalExternalPosts
                    self.saveExternalPosts()
                    
                    // Обновляем lastUpdateId
                    if let lastUpdate = updates.last {
                        self.lastUpdateId = (lastUpdate.updateId ?? 0) + 1
                        let userDefaults = UserDefaults(suiteName: Self.appGroup)
                        userDefaults?.set(self.lastUpdateId, forKey: "lastUpdateId")
                    }
                    
                    Logger.info("Fetched \(finalExternalPosts.count) external posts", log: Logger.telegram)
                    completion(true)
                }
                
            } catch {
                await MainActor.run {
                    Logger.error("Failed to fetch external posts: \(error)", log: Logger.telegram)
                    completion(false)
                }
            }
        }
    }
    func saveExternalPosts() {
        guard let data = try? JSONEncoder().encode(externalPosts) else { return }
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(data, forKey: "externalPosts")
    }
    func loadExternalPosts() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        guard let data = userDefaults?.data(forKey: "externalPosts"),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            externalPosts = []
            return
        }
        externalPosts = decoded
    }
    func deleteBotMessages(completion: @escaping (Bool) -> Void) {
        // TODO: Реализовать с новым TelegramService
        completion(false)
    }
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        // TODO: Реализовать с новым TelegramService
        completion(false)
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
        return posts + externalPosts
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
    private static let notifEnabledKey = "notificationsEnabled"
    private static let notifIntervalKey = "notificationIntervalHours"
    private static let notifModeKey = "notificationMode"
    
    func saveNotificationSettings() {
        let ud = UserDefaults(suiteName: Self.appGroup)
        ud?.set(notificationsEnabled, forKey: Self.notifEnabledKey)
        ud?.set(notificationMode.rawValue, forKey: Self.notifModeKey)
        ud?.set(notificationIntervalHours, forKey: Self.notifIntervalKey)
    }
    
    func loadNotificationSettings() {
        let ud = UserDefaults(suiteName: Self.appGroup)
        notificationsEnabled = ud?.bool(forKey: Self.notifEnabledKey) ?? false
        if let modeRaw = ud?.string(forKey: Self.notifModeKey), let mode = NotificationMode(rawValue: modeRaw) {
            notificationMode = mode
        } else {
            notificationMode = .hourly
        }
        notificationIntervalHours = ud?.integer(forKey: Self.notifIntervalKey) == 0 ? 1 : ud!.integer(forKey: Self.notifIntervalKey)
    }
}

// MARK: - Notification Logic
extension PostStore {
    func requestNotificationPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleNotifications() }
                else { self.notificationsEnabled = false }
            }
        }
    }
    
    func scheduleNotifications() {
        notificationService.scheduleNotifications()
    }
    
    func cancelAllNotifications() {
        notificationService.cancelAllNotifications()
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
        if !hasTodayPost || (reportStatus == .done && hasTodayPost) {
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
        goodTags = localService.loadGoodTags()
    }
    func saveGoodTags(_ tags: [String]) {
        localService.saveGoodTags(tags)
        self.goodTags = tags
    }
    func addGoodTag(_ tag: String) {
        localService.addGoodTag(tag)
        loadGoodTags()
    }
    func removeGoodTag(_ tag: String) {
        localService.removeGoodTag(tag)
        loadGoodTags()
    }
    func updateGoodTag(old: String, new: String) {
        localService.updateGoodTag(old: old, new: new)
        loadGoodTags()
    }
    func loadBadTags() {
        badTags = localService.loadBadTags()
    }
    func saveBadTags(_ tags: [String]) {
        localService.saveBadTags(tags)
        self.badTags = tags
    }
    func addBadTag(_ tag: String) {
        localService.addBadTag(tag)
        loadBadTags()
    }
    func removeBadTag(_ tag: String) {
        localService.removeBadTag(tag)
        loadBadTags()
    }
    func updateBadTag(old: String, new: String) {
        localService.updateBadTag(old: old, new: new)
        loadBadTags()
    }

    // MARK: - Автоотправка в Telegram
    func loadAutoSendSettings() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        autoSendToTelegram = userDefaults?.bool(forKey: "autoSendToTelegram") ?? false
        if let date = userDefaults?.object(forKey: "autoSendTime") as? Date {
            print("[AutoSend][LOAD] Загружено время автоотправки: \(date)")
            autoSendTime = date
        } else {
            print("[AutoSend][LOAD] Время автоотправки не найдено, используется дефолт: \(autoSendTime)")
        }
        lastAutoSendStatus = userDefaults?.string(forKey: "lastAutoSendStatus")
        saveAutoSendSettings()
    }
    func saveAutoSendSettings() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(autoSendToTelegram, forKey: "autoSendToTelegram")
        userDefaults?.set(autoSendTime, forKey: "autoSendTime")
        userDefaults?.set(lastAutoSendStatus, forKey: "lastAutoSendStatus")
        print("[AutoSend][SAVE] Сохраняю время автоотправки: \(autoSendTime)")
    }
    func scheduleAutoSendIfNeeded() {
        // MVP: использовать Timer для планирования автоотправки (BGTaskScheduler — для продакшена)
        autoSendTimer?.invalidate()
        guard autoSendToTelegram else { print("[AutoSend] Disabled"); return }
        let now = Date()
        let cal = Calendar.current
        let todaySend = cal.date(
            bySettingHour: cal.component(.hour, from: autoSendTime),
            minute: cal.component(.minute, from: autoSendTime),
            second: 0,
            of: now
        ) ?? autoSendTime
        let interval = todaySend.timeIntervalSince(now)
        print("[AutoSend] Scheduling auto send for", todaySend, "in", interval, "seconds")
        if interval > 0 {
            // Таймер только для debug/MVP, не для BGTaskScheduler
#if DEBUG
            autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.performAutoSendReport()
            }
#endif
        }
    }
    private var autoSendTimer: Timer? {
        get { objc_getAssociatedObject(self, &PostStore.autoSendTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &PostStore.autoSendTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var autoSendTimerKey: UInt8 = 0
    func performAutoSendReport() {
        // Проверяем, не наступил ли новый день перед автоотправкой
        checkForNewDay()
        
        telegramService.performAutoSendReport { [weak self] in
            // Обновляем статус после отправки только если это еще сегодня
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Проверяем еще раз, что мы все еще в том же дне
                let calendar = Calendar.current
                let now = Date()
                let today = calendar.startOfDay(for: now)
                
                if calendar.isDate(self.currentDay, inSameDayAs: today) {
                    // Обновляем статус через updateReportStatus() для правильной логики
                    self.updateReportStatus()
                    print("[DEBUG] Автоотправка: статус обновлен через updateReportStatus()")
                } else {
                    print("[DEBUG] Автоотправка: новый день наступил, статус не изменен")
                }
                
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    /// Автоматическая отправка всех отчетов за сегодня (кастомный и обычный)
    func autoSendAllReportsForToday(completion: (() -> Void)? = nil) {
        telegramService.autoSendAllReportsForToday()
        completion?()
    }
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        telegramService.sendToTelegram(text: text, completion: completion)
    }
    
    // MARK: - Telegram Message Conversion
    
    /// Преобразует сообщение Telegram в объект Post
    private func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? {
        // Если есть текст — обычный текстовый отчет
        if let text = message.text, !text.isEmpty {
            let post = Post(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(message.date ?? 0)),
                goodItems: [],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: message.from?.username,
                authorFirstName: message.from?.firstName,
                authorLastName: message.from?.lastName,
                isExternal: true,
                externalVoiceNoteURLs: nil,
                externalText: text,
                externalMessageId: message.messageId,
                authorId: message.from?.id
            )
            return post
        }
        // Если есть голосовое сообщение
        if let voice = message.voice {
            // Формируем ссылку на файл Telegram (file_id)
            let token = telegramToken ?? ""
            let fileURL = URL(string: "https://api.telegram.org/file/bot\(token)/\(voice.fileId ?? "")")
            let post = Post(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(message.date ?? 0)),
                goodItems: [],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: message.from?.username,
                authorFirstName: message.from?.firstName,
                authorLastName: message.from?.lastName,
                isExternal: true,
                externalVoiceNoteURLs: fileURL != nil ? [fileURL!] : nil,
                externalText: message.caption ?? "[Голосовое сообщение]",
                externalMessageId: message.messageId,
                authorId: message.from?.id
            )
            return post
        }
        // Если есть аудио
        if let audio = message.audio {
            let token = telegramToken ?? ""
            let fileURL = URL(string: "https://api.telegram.org/file/bot\(token)/\(audio.fileId ?? "")")
            let post = Post(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(message.date ?? 0)),
                goodItems: [],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: message.from?.username,
                authorFirstName: message.from?.firstName,
                authorLastName: message.from?.lastName,
                isExternal: true,
                externalVoiceNoteURLs: fileURL != nil ? [fileURL!] : nil,
                externalText: message.caption ?? "[Аудио сообщение]",
                externalMessageId: message.messageId,
                authorId: message.from?.id
            )
            return post
        }
        // Если есть документ
        if let document = message.document {
            let token = telegramToken ?? ""
            let fileURL = URL(string: "https://api.telegram.org/file/bot\(token)/\(document.fileId ?? "")")
            let post = Post(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(message.date ?? 0)),
                goodItems: [],
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .external,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: message.from?.username,
                authorFirstName: message.from?.firstName,
                authorLastName: message.from?.lastName,
                isExternal: true,
                externalVoiceNoteURLs: fileURL != nil ? [fileURL!] : nil,
                externalText: document.fileName ?? "[Документ]",
                externalMessageId: message.messageId,
                authorId: message.from?.id
            )
            return post
        }
        // Если ничего не подошло — не создаём Post
        return nil
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