import Foundation
import AVFoundation
import WidgetKit
import UserNotifications

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

// MARK: - Статус отчёта
enum ReportStatus: String, Codable {
    case notStarted
    case inProgress
    case done
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
    static let appGroup = "group.com.katapios.LazyBones"
    @Published var posts: [Post] = []
    @Published var externalPosts: [Post] = [] // Внешние отчеты из Telegram
    @Published var telegramToken: String? = nil
    @Published var telegramChatId: String? = nil
    @Published var telegramBotId: String? = nil
    @Published var lastUpdateId: Int? = nil
    @Published var reportStatus: ReportStatus = .notStarted
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
            scheduleAutoSendIfNeeded()
        }
    }
    @Published var autoSendTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            saveAutoSendSettings()
            scheduleAutoSendIfNeeded()
        }
    }
    @Published var lastAutoSendStatus: String? = nil

    init(localService: LocalReportService = .shared) {
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
        loadAutoSendSettings()
        scheduleAutoSendIfNeeded()
    }

    deinit {
        stopTimer()
    }

    /// Загрузка отчётов из LocalReportService
    func load() {
        posts = localService.loadPosts()
    }
    /// Сохранение отчётов через LocalReportService
    func save() {
        localService.savePosts(posts)
    }
    /// Добавление нового отчёта
    func add(post: Post) {
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
        print("[DEBUG] add: published=\(post.published), forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
    }
    /// Очистка всех отчётов
    func clear() {
        posts = []
        localService.clearPosts()
        updateReportStatus()
        WidgetCenter.shared.reloadAllTimelines()
    }
    /// Обновление существующего отчёта по id
    func update(post: Post) {
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
            print("[DEBUG] update: published=\(post.published), forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
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
        telegramService = TelegramService(token: token, chatId: chatId)
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
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        guard let telegramService = telegramService else { completion(false); return }
        let offset = lastUpdateId != nil ? lastUpdateId! + 1 : nil
        telegramService.fetchMessages(offset: offset, limit: 20, botId: telegramBotId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messages):
                    if !messages.isEmpty {
                        if let lastMessage = messages.last {
                            self.saveLastUpdateId(lastMessage.updateId)
                        }
                        let posts = messages.map { msg in
                            Post(
                                id: UUID(),
                                date: msg.date,
                                goodItems: [],
                                badItems: [],
                                published: true,
                                voiceNotes: [],
                                type: .external,
                                authorUsername: msg.authorUsername,
                                authorFirstName: msg.authorFirstName,
                                authorLastName: msg.authorLastName,
                                isExternal: true,
                                externalVoiceNoteURLs: nil,
                                externalText: msg.caption ?? msg.text,
                                externalMessageId: msg.id,
                                authorId: msg.authorId
                            )
                        }
                        self.externalPosts.append(contentsOf: posts)
                        self.externalPosts.sort { $0.date > $1.date }
                        self.saveExternalPosts()
                    }
                    completion(true)
                case .failure:
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
        guard let telegramService = telegramService else { completion(false); return }
        let botMessageIds = externalPosts.compactMap { post -> Int? in
            if let botId = telegramBotId, let authorId = post.authorId, String(authorId) == botId {
                return post.externalMessageId
            }
            return post.externalMessageId
        }
        if botMessageIds.isEmpty {
            completion(true)
            return
        }
        telegramService.deleteMessages(messageIds: botMessageIds) { success in
            DispatchQueue.main.async {
                if success {
                    self.externalPosts.removeAll { post in
                        botMessageIds.contains(post.externalMessageId ?? 0)
                    }
                    self.saveExternalPosts()
                }
                completion(success)
            }
        }
    }
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        guard let telegramService = telegramService else { completion(false); return }
        telegramService.fetchMessages(offset: nil, limit: 100, botId: telegramBotId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messages):
                    let botMessageIds = messages.compactMap { message -> Int? in
                        if message.isFromBot {
                            return message.id
                        }
                        return nil
                    }
                    if botMessageIds.isEmpty {
                        completion(true)
                        return
                    }
                    telegramService.deleteMessages(messageIds: botMessageIds) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.lastUpdateId = nil
                                let userDefaults = UserDefaults(suiteName: Self.appGroup)
                                userDefaults?.removeObject(forKey: "lastUpdateId")
                            }
                            completion(success)
                        }
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
    // MARK: - Report Status
    func updateReportStatus() {
        if forceUnlock {
            reportStatus = .notStarted
            localService.saveReportStatus(.notStarted)
            WidgetCenter.shared.reloadAllTimelines()
            if notificationsEnabled { scheduleNotifications() }
            print("[DEBUG] updateReportStatus (forceUnlock): forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
            return
        }
        let today = Calendar.current.startOfDay(for: Date())
        if let todayPost = posts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            if todayPost.published {
                reportStatus = .done
            } else if !todayPost.goodItems.isEmpty || !todayPost.badItems.isEmpty || !todayPost.voiceNotes.isEmpty {
                reportStatus = .inProgress
            } else {
                reportStatus = .notStarted
            }
        } else {
            reportStatus = .notStarted
        }
        localService.saveReportStatus(reportStatus)
        WidgetCenter.shared.reloadAllTimelines()
        if notificationsEnabled { scheduleNotifications() }
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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
        if reportStatus == .done {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            timeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            timeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            timeLeft = "До конца: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            timeLeft = "Время отчёта истекло"
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
            autoSendTime = date
        }
        lastAutoSendStatus = userDefaults?.string(forKey: "lastAutoSendStatus")
        saveAutoSendSettings() // Гарантируем, что autoSendTime всегда актуален
    }
    func saveAutoSendSettings() {
        let userDefaults = UserDefaults(suiteName: Self.appGroup)
        userDefaults?.set(autoSendToTelegram, forKey: "autoSendToTelegram")
        userDefaults?.set(autoSendTime, forKey: "autoSendTime")
        userDefaults?.set(lastAutoSendStatus, forKey: "lastAutoSendStatus")
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
            autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.performAutoSendReport()
            }
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
                self?.reportStatus = ReportStatus.done
                self?.localService.saveReportStatus(ReportStatus.done)
                self?.forceUnlock = false
                self?.localService.saveForceUnlock(false)
                // Сбросить временные статусы, если нужно
            }
        }
    }
    private func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            print("[AutoSend] Telegram credentials missing")
            completion(false)
            return
        }
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        guard let url = URL(string: urlString) else { print("[AutoSend] Invalid URL"); completion(false); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let params = ["chat_id": chatId, "text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { print("[AutoSend] Telegram send error: \(error)"); completion(false); return }
            print("[AutoSend] Telegram send success")
            completion(true)
        }
        task.resume()
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