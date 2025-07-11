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
    
    private let userDefaults: UserDefaults?
    private let key = "posts"
    private let tokenKey = "telegramToken"
    private let chatIdKey = "telegramChatId"
    
    // Кэширование внешних отчетов
    private let externalKey = "externalPosts"
    
    init() {
        userDefaults = UserDefaults(suiteName: Self.appGroup)
        load()
        loadTelegramSettings()
        loadExternalPosts() // Загружаем внешние отчеты при инициализации
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
    }
    
    /// Очистка всех отчётов
    func clear() {
        posts = []
        save()
    }
    
    /// Обновление существующего отчёта по id
    func update(post: Post) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
            save()
        }
    }
    
    /// Получение имени устройства
    func getDeviceName() -> String {
        return userDefaults?.string(forKey: "deviceName") ?? "Устройство"
    }
    
    // MARK: - Telegram Integration
    func saveTelegramSettings(token: String?, chatId: String?) {
        telegramToken = token
        telegramChatId = chatId
        userDefaults?.set(token, forKey: tokenKey)
        userDefaults?.set(chatId, forKey: chatIdKey)
    }
    
    func loadTelegramSettings() {
        telegramToken = userDefaults?.string(forKey: tokenKey)
        telegramChatId = userDefaults?.string(forKey: chatIdKey)
    }
    
    // Загрузка внешних отчетов из Telegram
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        guard let token = telegramToken, let chatId = telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            completion(false)
            return
        }
        let api = TelegramAPIService(token: token, chatId: chatId)
        // TODO: offset, lazy loading, batching
        api.fetchMessages(offset: nil, limit: 20) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let messages):
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
                            externalText: msg.caption ?? msg.text // сначала caption, потом text
                        )
                    }
                    self.externalPosts = posts
                    self.saveExternalPosts()
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