import Foundation
import Combine

/// Протокол для интеграции с Telegram
protocol TelegramIntegrationServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    var externalPosts: [Post] { get set }
    var telegramToken: String? { get set }
    var telegramChatId: String? { get set }
    var telegramBotId: String? { get set }
    var lastUpdateId: Int? { get set }
    
    // MARK: - Settings Management
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?)
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?)
    func saveLastUpdateId(_ updateId: Int)
    
    // MARK: - External Posts Management
    func fetchExternalPosts(completion: @escaping (Bool) -> Void)
    func saveExternalPosts()
    func loadExternalPosts()
    func deleteBotMessages(completion: @escaping (Bool) -> Void)
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void)
    
    // MARK: - Message Conversion
    func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post?
    
    // MARK: - Combined Posts
    func getAllPosts() -> [Post]
}

/// Сервис для интеграции с Telegram
class TelegramIntegrationService: TelegramIntegrationServiceProtocol {
    
    // MARK: - Published Properties
    @Published var externalPosts: [Post] = []
    @Published var telegramToken: String? = nil
    @Published var telegramChatId: String? = nil
    @Published var telegramBotId: String? = nil
    @Published var lastUpdateId: Int? = nil
    
    // MARK: - Dependencies
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let telegramService: TelegramServiceProtocol?
    
    // MARK: - Initialization
    init(
        userDefaultsManager: UserDefaultsManagerProtocol,
        telegramService: TelegramServiceProtocol?
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.telegramService = telegramService
        
        _ = loadTelegramSettings()
        loadExternalPosts()
    }
    
    // MARK: - Settings Management
    
    func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {
        telegramToken = token
        telegramChatId = chatId
        telegramBotId = botId
        
        userDefaultsManager.set(token, forKey: "telegramToken")
        userDefaultsManager.set(chatId, forKey: "telegramChatId")
        userDefaultsManager.set(botId, forKey: "telegramBotId")
        
        // Обновляем TelegramService в DI контейнере
        if let token = token, !token.isEmpty {
            DependencyContainer.shared.registerTelegramService(token: token)
        }
    }
    
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        telegramToken = userDefaultsManager.string(forKey: "telegramToken")
        telegramChatId = userDefaultsManager.string(forKey: "telegramChatId")
        telegramBotId = userDefaultsManager.string(forKey: "telegramBotId")
        lastUpdateId = userDefaultsManager.integer(forKey: "lastUpdateId")
        
        // Обновляем TelegramService в DI контейнере если есть токен
        if let token = telegramToken, !token.isEmpty {
            DependencyContainer.shared.registerTelegramService(token: token)
        }
        
        return (telegramToken, telegramChatId, telegramBotId)
    }
    
    func saveLastUpdateId(_ updateId: Int) {
        lastUpdateId = updateId
        userDefaultsManager.set(updateId, forKey: "lastUpdateId")
    }
    
    // MARK: - External Posts Management
    
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
                guard let telegramServiceForUpdates = telegramService else {
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
                
                Logger.debug("Получено сообщений из Telegram: \(messages.count)", log: Logger.telegram)
                
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
                        self.userDefaultsManager.set(self.lastUpdateId, forKey: "lastUpdateId")
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
        userDefaultsManager.set(data, forKey: "externalPosts")
    }
    
    func loadExternalPosts() {
        guard let data = userDefaultsManager.data(forKey: "externalPosts"),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            externalPosts = []
            return
        }
        externalPosts = decoded
    }
    
    func deleteBotMessages(completion: @escaping (Bool) -> Void) {
        // TODO: Реализовать с новым TelegramService
        Logger.warning("deleteBotMessages not implemented yet", log: Logger.telegram)
        completion(false)
    }
    
    func deleteAllBotMessages(completion: @escaping (Bool) -> Void) {
        // TODO: Реализовать с новым TelegramService
        Logger.warning("deleteAllBotMessages not implemented yet", log: Logger.telegram)
        completion(false)
    }
    
    // MARK: - Message Conversion
    
    func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? {
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
    
    // MARK: - Combined Posts
    
    func getAllPosts() -> [Post] {
        // Возвращаем только внешние отчеты, так как локальные отчеты будут добавлены в PostStore
        return externalPosts
    }
}

// MARK: - Typealias for easier usage
typealias TelegramIntegrationServiceType = any TelegramIntegrationServiceProtocol 