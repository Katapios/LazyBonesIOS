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
    let published: Bool
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

// MARK: - Статус отчёта (используется из ReportModel.swift)

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
    static let appGroup = "group.com.katapios.LazyBones"
    @Published var posts: [Post] = []
    @Published var externalPosts: [Post] = [] // Внешние отчеты из Telegram
    @Published var telegramToken: String? = nil
    @Published var telegramChatId: String? = nil
    @Published var telegramBotId: String? = nil
    @Published var lastUpdateId: Int? = nil
    @Published var reportStatus: LazyBones.ReportStatus = .notStarted
    @Published var forceUnlock: Bool = false
    @Published var timeLeft: String = "" // Новое свойство для отображения таймера
    private var timer: Timer? = nil
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
    private let localService: LocalReportService
    private var telegramService: TelegramService?
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

    init(localService: LocalReportService = .shared) {
        print("[DEBUG][INIT] PostStore инициализирован")
        self.localService = localService
        load()
        loadTelegramSettings()
        loadExternalPosts()
        loadReportStatus()
        loadForceUnlock()
        loadNotificationSettings()
        updateReportStatus()
        updateTimeLeft()
        startTimer()
        loadGoodTags()
        loadBadTags()
        loadAutoSendSettings() // autoSendTime загружается из UserDefaults
        scheduleAutoSendIfNeeded()
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
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            telegramService = nil
            return
        }
        telegramService = TelegramService(token: token)
    }
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        telegramToken = token
        telegramChatId = chatId
        telegramBotId = botId
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(token, forKey: "telegramToken")
        userDefaults?.set(chatId, forKey: "telegramChatId")
        userDefaults?.set(botId, forKey: "telegramBotId")
        setTelegramService()
    }
    func loadTelegramSettings() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        telegramToken = userDefaults?.string(forKey: "telegramToken")
        telegramChatId = userDefaults?.string(forKey: "telegramChatId")
        telegramBotId = userDefaults?.string(forKey: "telegramBotId")
        lastUpdateId = userDefaults?.integer(forKey: "lastUpdateId")
        setTelegramService()
    }
    func saveLastUpdateId(_ updateId: Int) {
        lastUpdateId = updateId
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(updateId, forKey: "lastUpdateId")
    }
    // Загрузка внешних отчетов из Telegram
    // TODO: Реализовать с новым TelegramService
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        // Временно отключено - нужно реализовать с новым TelegramService
        completion(false)
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
    // MARK: - Report Status
    func updateReportStatus() {
        if forceUnlock {
            let newStatus: LazyBones.ReportStatus = .notStarted
            if reportStatus != newStatus {
                reportStatus = newStatus
                localService.saveReportStatus(newStatus)
                WidgetCenter.shared.reloadAllTimelines()
                if notificationsEnabled { scheduleNotifications() }
            }
            print("[DEBUG] updateReportStatus (forceUnlock): forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
            return
        }
        let today = Calendar.current.startOfDay(for: Date())
        // Новый алгоритм:
        // 1. Если есть опубликованный обычный отчет за сегодня — .done
        // 2. Если есть обычный отчет за сегодня (не опубликован, но есть good/bad/voice) — .inProgress
        // 3. Если есть только кастомный отчет за сегодня — .inProgress
        // 4. Иначе — .notStarted
        let newStatus: LazyBones.ReportStatus
        if let regular = posts.first(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            if regular.published {
                newStatus = .done
            } else if !regular.goodItems.isEmpty || !regular.badItems.isEmpty || !regular.voiceNotes.isEmpty {
                newStatus = .inProgress
            } else {
                newStatus = .notStarted
            }
        } else if posts.contains(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            newStatus = .inProgress
        } else {
            newStatus = .notStarted
        }
        
        // Обновляем только если статус изменился
        if reportStatus != newStatus {
            reportStatus = newStatus
            localService.saveReportStatus(newStatus)
            WidgetCenter.shared.reloadAllTimelines()
            if notificationsEnabled { scheduleNotifications() }
        }
        print("[DEBUG] updateReportStatus: forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
    }
    func loadReportStatus() {
        reportStatus = localService.getReportStatus()
    }
    /// Разблокировать возможность создания отчёта (не трогая локальные отчёты)
    func unlockReportCreation() {
        let today = Calendar.current.startOfDay(for: Date())
        // Удаляем опубликованный отчет за сегодня, если есть
        posts.removeAll { post in
            Calendar.current.isDate(post.date, inSameDayAs: today) && post.published
        }
        reportStatus = .notStarted
        save()
        localService.saveReportStatus(.notStarted)
        WidgetCenter.shared.reloadAllTimelines()
        print("[DEBUG] unlock: удален опубликованный отчет за сегодня, reportStatus=\(reportStatus)")
    }
    func loadForceUnlock() {
        forceUnlock = localService.getForceUnlock()
    }
    // Объединить локальные и внешние отчеты для отображения
    var allPosts: [Post] {
        return posts + externalPosts
    }

    // MARK: - Notification Settings
    private let notifEnabledKey = "notificationsEnabled"
    private let notifIntervalKey = "notificationIntervalHours"
    private let notifModeKey = "notificationMode"
    func saveNotificationSettings() {
        let ud = UserDefaults(suiteName: Self.appGroup)
        ud?.set(notificationsEnabled, forKey: notifEnabledKey)
        ud?.set(notificationMode.rawValue, forKey: notifModeKey)
        ud?.set(notificationIntervalHours, forKey: notifIntervalKey)
    }
    func loadNotificationSettings() {
        let ud = UserDefaults(suiteName: Self.appGroup)
        notificationsEnabled = ud?.bool(forKey: notifEnabledKey) ?? false
        if let modeRaw = ud?.string(forKey: notifModeKey), let mode = NotificationMode(rawValue: modeRaw) {
            notificationMode = mode
        } else {
            notificationMode = .hourly
        }
        notificationIntervalHours = ud?.integer(forKey: notifIntervalKey) == 0 ? 1 : ud!.integer(forKey: notifIntervalKey)
    }

    // MARK: - Notification Logic
    func requestNotificationPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleNotifications() }
                else { self.notificationsEnabled = false }
            }
        }
    }
    func scheduleNotifications() {
        cancelAllNotifications()
        guard notificationsEnabled else { return }
        // Не создавать уведомления, если отчёт уже отправлен
        if reportStatus == .done {
            return
        }
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let calendar = Calendar.current
        let startHour = notificationStartHour
        let endHour = notificationEndHour
        var hours: [Int] = []
        switch notificationMode {
        case .hourly:
            hours = Array(stride(from: startHour, to: endHour, by: 1))
        case .twice:
            hours = [startHour, endHour - 1]
        }
        // Только оставшиеся уведомления на сегодня
        let currentHour = calendar.component(.hour, from: now)
        let todayHours = hours.filter { $0 >= currentHour }
        for hour in todayHours {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            dateComponents.hour = hour
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let content = UNMutableNotificationContent()
            let isLast = hour == (endHour - 1)
            content.title = isLast ? "Поторопись! До конца времени отчёта 1 час" : "Не забудь заполнить отчет Лаботрясов!"
            content.body = isLast ? "Остался всего 1 час, чтобы отправить отчёт!" : "До блокировки отчета: \(self.timeLeftString(untilHour: endHour))\nНе облажайся, бро! верю в тебя."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "LazyBonesNotif_\(hour)", content: content, trigger: trigger)
            center.add(request)
            // DEBUG LOG
            let type = isLast ? "[ПРЕДОСТЕРЕГАЮЩЕЕ]" : "[ОБЫЧНОЕ]"
            let scheduledDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            print("[DEBUG][NOTIF] \(type) Уведомление на: \(formatter.string(from: scheduledDate)), сейчас: \(formatter.string(from: now))")
        }
    }
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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

    // MARK: - Timer Logic
    /// Таймер
    func startTimer() {
        stopTimer()
        updateTimeLeft()
        
        // Умная логика обновления: чаще в критических моментах
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: notificationStartHour, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: notificationEndHour, minute: 0, second: 0, of: now)!
        
        // Если до начала или конца периода меньше часа - обновляем каждые 10 секунд
        let timeToStart = start.timeIntervalSince(now)
        let timeToEnd = end.timeIntervalSince(now)
        let isCriticalTime = (timeToStart > 0 && timeToStart < 3600) || (timeToEnd > 0 && timeToEnd < 3600)
        
        let interval: TimeInterval = isCriticalTime ? 10 : 30
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateTimeLeft()
        }
    }
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    func updateTimeLeft() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: notificationStartHour, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: notificationEndHour, minute: 0, second: 0, of: now)!
        // --- Новый день: если нет отчёта на сегодня или дата отчёта не совпадает с сегодняшней, обновить статус ---
        let today = calendar.startOfDay(for: now)
        let hasTodayPost = posts.contains(where: { calendar.isDate($0.date, inSameDayAs: today) })
        if !hasTodayPost || (reportStatus == .done && hasTodayPost) {
            updateReportStatus()
        }
        
        // Вычисляем новое значение timeLeft
        let newTimeLeft: String
        if reportStatus == .done {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            newTimeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            newTimeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            newTimeLeft = "До конца: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            newTimeLeft = "Время отчёта истекло"
        }
        
        // Обновляем только если значение изменилось
        if timeLeft != newTimeLeft {
            timeLeft = newTimeLeft
        }
    }
    // MARK: - Good/Bad Tags
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
        print("[AutoSend] performAutoSendReport called at", Date())
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Найти обычный или кастомный отчет за сегодня
        let regular = posts.first(where: { $0.type == .regular && cal.isDate($0.date, inSameDayAs: today) })
        let custom = posts.first(where: { $0.type == .custom && cal.isDate($0.date, inSameDayAs: today) })
        let hasRegular = regular != nil && (!regular!.goodItems.isEmpty || !regular!.badItems.isEmpty)
        let hasCustom = custom != nil && (!custom!.goodItems.isEmpty || (custom!.evaluationResults?.contains(true) == true))
        var textToSend = ""
        if hasRegular {
            textToSend = "Обычный отчет за сегодня:\n" + (regular!.goodItems + regular!.badItems).joined(separator: "\n")
        } else if hasCustom {
            textToSend = "Кастомный отчет за сегодня:\n" + (custom!.goodItems).enumerated().map { idx, item in
                let mark = (custom!.evaluationResults?[idx] ?? false) ? "✅" : "❌"
                return "\(mark) \(item)"
            }.joined(separator: "\n")
        } else {
            textToSend = "Сегодня я получил медаль истинного LABотряса, потому, что не сделал никакого отчета"
        }
        print("[AutoSend] Sending to Telegram: \n\(textToSend)")
        // Отправить в Telegram (асинхронно)
        sendToTelegram(text: textToSend) { [weak self] success in
            DispatchQueue.main.async {
                print("[AutoSend] Telegram send result:", success)
                self?.lastAutoSendStatus = success ? "Отправлено в \(self?.autoSendTime.formatted(date: .omitted, time: .shortened) ?? "")" : "Ошибка отправки"
                self?.saveAutoSendSettings()
                // Блокировать отправку/редактирование до следующего дня
                        self?.reportStatus = LazyBones.ReportStatus.done
        self?.localService.saveReportStatus(LazyBones.ReportStatus.done)
                self?.forceUnlock = false
                self?.localService.saveForceUnlock(false)
                WidgetCenter.shared.reloadAllTimelines()
                // Отправить локальное уведомление
                if success {
                    self?.sendLocalNotification(title: "Отчет отправлен", body: "Ваш отчет был автоматически отправлен в Telegram.")
                } else {
                    self?.sendLocalNotification(title: "Ошибка отправки", body: "Не удалось автоматически отправить отчет в Telegram.")
                }
            }
        }
    }
    /// Автоматическая отправка всех отчетов за сегодня (кастомный и обычный)
    func autoSendAllReportsForToday(completion: (() -> Void)? = nil) {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        
        // Проверка: отправляем только в промежутке 22:01-23:59
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let currentTimeInMinutes = hour * 60 + minute
        let startTimeInMinutes = 22 * 60 + 1  // 22:01
        let endTimeInMinutes = 23 * 60 + 59   // 23:59
        
        if currentTimeInMinutes < startTimeInMinutes || currentTimeInMinutes > endTimeInMinutes {
            print("[AutoSend] Время вне диапазона 22:01-23:59. Текущее время: \(hour):\(minute)")
            completion?()
            return
        }
        
        // Получаем отчеты за сегодня
        let regular = posts.first(where: { $0.type == .regular && cal.isDate($0.date, inSameDayAs: today) })
        let customReport = posts.first(where: { $0.type == .custom && cal.isDate($0.date, inSameDayAs: today) })
        
        // Проверяем, отправлял ли пользователь отчеты вручную
        let regularManuallySent = regular?.published ?? false
        let customManuallySent = customReport?.published ?? false
        
        // Если пользователь отправил оба отчета вручную, автоотправка не нужна
        if regularManuallySent && customManuallySent {
            print("[AutoSend] Пользователь отправил оба отчета вручную, автоотправка не требуется")
            completion?()
            return
        }
        
        // Проверяем, была ли уже автоотправка сегодня
        if let last = lastAutoSendDate, cal.isDate(last, inSameDayAs: today) {
            print("[AutoSend] Уже отправляли сегодня: \(last)")
            completion?()
            return
        }
        var sentCount = 0
        var toSend = 0
        func done() {
            sentCount += 1
            if sentCount == toSend { completion?() }
        }
        // --- Кастомный отчет ---
        if let custom = customReport, !custom.goodItems.isEmpty {
            if !customManuallySent {
                toSend += 1
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "ru_RU")
                dateFormatter.dateStyle = .full
                let dateStr = dateFormatter.string(from: custom.date)
                let deviceName = getDeviceName()
                var message = "\u{1F4C5} <b>План на день за \(dateStr)</b>\n"
                message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
                if !custom.goodItems.isEmpty {
                    message += "<b>✅ План:</b>\n"
                    for (index, item) in custom.goodItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                }
                sendToTelegram(text: message) { _ in done() }
            } else {
                print("[AutoSend] Кастомный отчет уже отправлен пользователем")
            }
        } else {
            toSend += 1
            sendToTelegram(text: "План на сегодня отсутствует.") { _ in done() }
        }
        
        // --- Обычный отчет ---
        if let regular = regular, (!regular.goodItems.isEmpty || !regular.badItems.isEmpty) {
            if !regularManuallySent {
                toSend += 1
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "ru_RU")
                dateFormatter.dateStyle = .full
                let dateStr = dateFormatter.string(from: regular.date)
                let deviceName = getDeviceName()
                var message = "\u{1F4C5} <b>Локальный отчет за \(dateStr)</b>\n"
                message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
                if !regular.goodItems.isEmpty {
                    message += "<b>✅ Я молодец:</b>\n"
                    for (index, item) in regular.goodItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                    message += "\n"
                }
                if !regular.badItems.isEmpty {
                    message += "<b>❌ Я не молодец:</b>\n"
                    for (index, item) in regular.badItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                }
                sendToTelegram(text: message) { _ in done() }
            } else {
                print("[AutoSend] Обычный отчет уже отправлен пользователем")
            }
        } else {
            toSend += 1
            sendToTelegram(text: "Локальный отчет за сегодня отсутствует.") { _ in done() }
        }
        
        // --- Если нет ни одного отчета ---
        if customReport == nil && regular == nil {
            toSend += 1
            sendToTelegram(text: "За сегодня не найдено ни одного отчета.") { _ in done() }
        }
        if toSend == 0 { 
            // Если нечего отправлять за сегодня, проверяем предыдущие дни
            sendUnsentReportsFromPreviousDays(completion: completion)
        } else {
            // После успешной отправки:
            self.lastAutoSendDate = now
        }
    }
    
    /// Отправка неотправленных отчетов за предыдущие дни
    private func sendUnsentReportsFromPreviousDays(completion: (() -> Void)? = nil) {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        
        // Проверяем отчеты за последние 7 дней (кроме сегодня)
        var unsentReports: [(Post, String)] = []
        
        for dayOffset in 1...7 {
            let targetDate = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let regular = posts.first(where: { $0.type == .regular && cal.isDate($0.date, inSameDayAs: targetDate) })
            let custom = posts.first(where: { $0.type == .custom && cal.isDate($0.date, inSameDayAs: targetDate) })
            
            // Проверяем обычный отчет
            if let regular = regular, (!regular.goodItems.isEmpty || !regular.badItems.isEmpty), !regular.published {
                unsentReports.append((regular, "Локальный отчет"))
            }
            
            // Проверяем кастомный отчет
            if let custom = custom, !custom.goodItems.isEmpty, !custom.published {
                unsentReports.append((custom, "План на день"))
            }
        }
        
        if unsentReports.isEmpty {
            print("[AutoSend] Нет неотправленных отчетов за предыдущие дни")
            completion?()
            return
        }
        
        print("[AutoSend] Найдено \(unsentReports.count) неотправленных отчетов за предыдущие дни")
        
        var sentCount = 0
        let totalToSend = unsentReports.count
        
        func done() {
            sentCount += 1
            if sentCount == totalToSend {
                print("[AutoSend] Все неотправленные отчеты отправлены")
                completion?()
            }
        }
        
        // Отправляем каждый неотправленный отчет
        for (post, reportType) in unsentReports {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ru_RU")
            dateFormatter.dateStyle = .full
            let dateStr = dateFormatter.string(from: post.date)
            let deviceName = getDeviceName()
            
            var message = "\u{1F4C5} <b>\(reportType) за \(dateStr)</b>\n"
            message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n"
            message += "\u{26A0} <b>Отправлено автоматически с задержкой</b>\n\n"
            
            if post.type == .custom {
                if !post.goodItems.isEmpty {
                    message += "<b>✅ План:</b>\n"
                    for (index, item) in post.goodItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                }
            } else {
                if !post.goodItems.isEmpty {
                    message += "<b>✅ Я молодец:</b>\n"
                    for (index, item) in post.goodItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                    message += "\n"
                }
                if !post.badItems.isEmpty {
                    message += "<b>❌ Я не молодец:</b>\n"
                    for (index, item) in post.badItems.enumerated() {
                        message += "\(index + 1). \(item)\n"
                    }
                }
            }
            
            sendToTelegram(text: message) { _ in done() }
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AutoSend] Ошибка отправки локального уведомления: \(error)")
            }
        }
    }
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            print("[AutoSend] Telegram credentials missing")
            completion(false)
            return
        }
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        guard let url = URL(string: urlString) else {
            print("[AutoSend] Invalid URL"); completion(false); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let params = ["chat_id": chatId, "text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[AutoSend] Telegram send error: \(error)"); completion(false); return }
            print("[AutoSend] Telegram send success")
            completion(true)
        }
        task.resume()
    }
}

extension PostStore {
    static func rescheduleBGTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.katapios.LazyBones.sendReport")
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