import Foundation
import AVFoundation

/// Модель отчёта пользователя
struct Post: Codable, Identifiable {
    let id: UUID
    let date: Date
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
    var voiceNotes: [VoiceNote] // Массив голосовых заметок
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

/// Протокол хранилища отчётов
protocol PostStoreProtocol: ObservableObject {
    var posts: [Post] { get set }
    func load()
    func save()
    func add(post: Post)
    func clear()
    func getDeviceName() -> String
}

// MARK: - Статус отчёта
enum ReportStatus: String, Codable {
    case notStarted
    case inProgress
    case done
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
    
    private let userDefaults: UserDefaults?
    private let key = "posts"
    private let tokenKey = "telegramToken"
    private let chatIdKey = "telegramChatId"
    private let botIdKey = "telegramBotId"
    private let lastUpdateIdKey = "lastUpdateId"
    private let reportStatusKey = "reportStatus"
    
    // Кэширование внешних отчетов
    private let externalKey = "externalPosts"
    
    init() {
        userDefaults = UserDefaults(suiteName: Self.appGroup)
        load()
        loadTelegramSettings()
        loadExternalPosts() // Загружаем внешние отчеты при инициализации
        loadReportStatus()
        updateReportStatus()
    }
    
    /// Загрузка отчётов из UserDefaults
    func load() {
        guard let data = userDefaults?.data(forKey: key) else {
            posts = []
            return
        }
        // Попытка декодировать как новый формат
        if let decoded = try? JSONDecoder().decode([Post].self, from: data) {
            posts = decoded.sorted { $0.date > $1.date }
        } else if let legacyDecoded = try? JSONDecoder().decode([LegacyPost].self, from: data) {
            // Миграция старых данных
            posts = legacyDecoded.map { legacy in
                let notes: [VoiceNote] = legacy.voiceNoteURL != nil ? [VoiceNote(id: UUID(), path: legacy.voiceNoteURL!)] : []
                return Post(id: legacy.id, date: legacy.date, goodItems: legacy.goodItems, badItems: legacy.badItems, published: legacy.published, voiceNotes: notes)
            }.sorted { $0.date > $1.date }
            save() // Сохраняем в новом формате
        } else {
            posts = []
        }
    }
    
    /// Сохранение отчётов в UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        userDefaults?.set(data, forKey: key)
    }
    
    /// Добавление нового отчёта
    func add(post: Post) {
        posts.append(post)
        save()
        updateReportStatus()
    }
    
    /// Очистка всех отчётов
    func clear() {
        posts = []
        save()
        updateReportStatus()
    }
    
    /// Обновление существующего отчёта по id
    func update(post: Post) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
            save()
            updateReportStatus()
        }
    }
    
    /// Получение имени устройства
    func getDeviceName() -> String {
        return userDefaults?.string(forKey: "deviceName") ?? "Устройство"
    }
    
    // MARK: - Telegram Integration
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        telegramToken = token
        telegramChatId = chatId
        telegramBotId = botId
        userDefaults?.set(token, forKey: tokenKey)
        userDefaults?.set(chatId, forKey: chatIdKey)
        userDefaults?.set(botId, forKey: botIdKey)
    }
    
    func loadTelegramSettings() {
        telegramToken = userDefaults?.string(forKey: tokenKey)
        telegramChatId = userDefaults?.string(forKey: chatIdKey)
        telegramBotId = userDefaults?.string(forKey: botIdKey)
        lastUpdateId = userDefaults?.integer(forKey: lastUpdateIdKey)
    }
    
    func saveLastUpdateId(_ updateId: Int) {
        lastUpdateId = updateId
        userDefaults?.set(updateId, forKey: lastUpdateIdKey)
    }
    
    // Загрузка внешних отчетов из Telegram
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            completion(false)
            return
        }
        let api = TelegramAPIService(token: token, chatId: chatId)
        
        // Используем offset для получения только новых сообщений
        let offset = lastUpdateId != nil ? lastUpdateId! + 1 : nil
        api.fetchMessages(offset: offset, limit: 20, botId: telegramBotId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messages):
                    if !messages.isEmpty {
                        // Сохраняем последний update_id для следующего запроса
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
                                authorUsername: msg.authorUsername,
                                authorFirstName: msg.authorFirstName,
                                authorLastName: msg.authorLastName,
                                isExternal: true,
                                externalVoiceNoteURLs: nil, // TODO: download voice if present
                                externalText: msg.caption ?? msg.text, // сначала caption, потом text
                                externalMessageId: msg.id, // сохраняем message_id
                                authorId: msg.authorId // сохраняем ID автора
                            )
                        }
                        
                        // Добавляем новые сообщения к существующим (не заменяем)
                        self.externalPosts.append(contentsOf: posts)
                        self.externalPosts.sort { $0.date > $1.date } // Сортируем по дате
                        self.saveExternalPosts()
                    }
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }
    }
    // Сохраняем внешние отчеты в кэш
    func saveExternalPosts() {
        guard let data = try? JSONEncoder().encode(externalPosts) else { return }
        userDefaults?.set(data, forKey: externalKey)
    }
    // Загружаем внешние отчеты из кэша
    func loadExternalPosts() {
        guard let data = userDefaults?.data(forKey: externalKey),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            externalPosts = []
            return
        }
        externalPosts = decoded
    }
    // Удалить только сообщения бота из Telegram
    func deleteBotMessages(completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            completion(false)
            return
        }
        
        // Фильтруем только сообщения бота (которые можно удалить)
        let botMessageIds = externalPosts.compactMap { post -> Int? in
            // Проверяем, что это сообщение от бота (если у нас есть botId)
            if let botId = telegramBotId, let authorId = post.authorId, String(authorId) == botId {
                return post.externalMessageId
            }
            // Если botId не указан, считаем все сообщения потенциально удаляемыми
            return post.externalMessageId
        }
        
        if botMessageIds.isEmpty {
            completion(true)
            return
        }
        
        let api = TelegramAPIService(token: token, chatId: chatId)
        api.deleteMessages(messageIds: botMessageIds) { success in
            DispatchQueue.main.async {
                if success {
                    // Удаляем из локального списка только те сообщения, которые были удалены
                    self.externalPosts.removeAll { post in
                        botMessageIds.contains(post.externalMessageId ?? 0)
                    }
                    self.saveExternalPosts()
                }
                completion(success)
            }
        }
    }
    
    // Удалить всю историю бота из Telegram (все сообщения бота)
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            completion(false)
            return
        }
        
        // Получаем все сообщения из Telegram и фильтруем только сообщения бота
        let api = TelegramAPIService(token: token, chatId: chatId)
        api.fetchMessages(offset: nil, limit: 100, botId: telegramBotId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messages):
                    // Фильтруем только сообщения бота
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
                    
                    // Удаляем все сообщения бота
                    api.deleteMessages(messageIds: botMessageIds) { success in
                        DispatchQueue.main.async {
                            if success {
                                // Сбрасываем lastUpdateId после успешного удаления всей истории
                                self.lastUpdateId = nil
                                self.userDefaults?.removeObject(forKey: self.lastUpdateIdKey)
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
        saveReportStatus()
    }
    func saveReportStatus() {
        userDefaults?.set(reportStatus.rawValue, forKey: reportStatusKey)
    }
    func loadReportStatus() {
        if let raw = userDefaults?.string(forKey: reportStatusKey), let status = ReportStatus(rawValue: raw) {
            reportStatus = status
        } else {
            reportStatus = .notStarted
        }
    }
    
    // Объединить локальные и внешние отчеты для отображения
    var allPosts: [Post] {
        return posts + externalPosts
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