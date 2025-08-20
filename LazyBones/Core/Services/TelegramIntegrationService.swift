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
    func resetLastUpdateId()
    func refreshTelegramService()
    
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
    
    // MARK: - Report Formatting
    func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String
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
    private var telegramService: TelegramServiceProtocol?
    
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
        
        // Используем специальный метод для сохранения настроек Telegram
        userDefaultsManager.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        
        // Обновляем TelegramService через абстракцию конфигурации
        let container = DependencyContainer.shared
        if let updater = container.resolve(TelegramConfigUpdaterProtocol.self) {
            updater.applyTelegramToken(token)
        }
        // Пытаемся пере-разрешить TelegramService с актуальным токеном
        if let resolved: TelegramServiceProtocol = container.resolve(TelegramServiceProtocol.self) {
            self.telegramService = resolved
        }
    }
    
    func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) {
        telegramToken = userDefaultsManager.string(forKey: "telegramToken")
        telegramChatId = userDefaultsManager.string(forKey: "telegramChatId")
        telegramBotId = userDefaultsManager.string(forKey: "telegramBotId")
        lastUpdateId = userDefaultsManager.integer(forKey: "lastUpdateId")
        
        // Обновляем TelegramService через абстракцию конфигурации
        let container = DependencyContainer.shared
        if let updater = container.resolve(TelegramConfigUpdaterProtocol.self) {
            updater.applyTelegramToken(telegramToken)
        }
        // Пытаемся пере-разрешить TelegramService с актуальным токеном
        if let resolved: TelegramServiceProtocol = container.resolve(TelegramServiceProtocol.self) {
            self.telegramService = resolved
        }
        
        return (telegramToken, telegramChatId, telegramBotId)
    }
    
    func saveLastUpdateId(_ updateId: Int) {
        lastUpdateId = updateId
        userDefaultsManager.set(updateId, forKey: "lastUpdateId")
    }
    
    func resetLastUpdateId() {
        lastUpdateId = nil
        userDefaultsManager.remove(forKey: "lastUpdateId")
        Logger.info("Last update ID reset", log: Logger.telegram)
    }
    
    func refreshTelegramService() {
        // Обновляем TelegramService через абстракцию конфигурации
        let container = DependencyContainer.shared
        if let updater = container.resolve(TelegramConfigUpdaterProtocol.self) {
            updater.applyTelegramToken(telegramToken)
        }
        // Пере-разрешаем TelegramService с актуальным токеном
        if let resolved: TelegramServiceProtocol = container.resolve(TelegramServiceProtocol.self) {
            self.telegramService = resolved
        }
    }
    
    // MARK: - External Posts Management
    
    func fetchExternalPosts(completion: @escaping (Bool) -> Void) {
        Logger.info("[ExtReports] Start fetchExternalPosts", log: Logger.telegram)
        
        // Проверяем, есть ли настройки Telegram
        Logger.debug("[ExtReports] Current settings: token set? \(telegramToken != nil && !(telegramToken ?? "").isEmpty), chatId: \(telegramChatId ?? "nil"), lastUpdateId: \(lastUpdateId.map(String.init) ?? "nil")", log: Logger.telegram)
        guard let token = telegramToken, !token.isEmpty else {
            Logger.warning("[ExtReports] Aborting: Telegram token is not set", log: Logger.telegram)
            completion(false)
            return
        }
        
        Task {
            do {
                Logger.info("[ExtReports] Calling getUpdates with offset=\(lastUpdateId.map(String.init) ?? "nil")", log: Logger.telegram)
                // Получаем TelegramService для обновлений
                var telegramServiceForUpdates = self.telegramService
                if telegramServiceForUpdates == nil {
                    let container = DependencyContainer.shared
                    if let resolved: TelegramServiceProtocol = container.resolve(TelegramServiceProtocol.self) {
                        self.telegramService = resolved
                        telegramServiceForUpdates = resolved
                    }
                }
                guard let telegramServiceForUpdates else {
                    Logger.error("[ExtReports] TelegramService not available after resolve", log: Logger.telegram)
                    completion(false)
                    return
                }
                
                // Получаем обновления из Telegram
                var updates = try await telegramServiceForUpdates.getUpdates(offset: lastUpdateId)
                // Резервный фетч без offset, если ничего не пришло, но offset задан
                if updates.isEmpty, lastUpdateId != nil {
                    Logger.info("[ExtReports] No updates with offset. Retrying without offset...", log: Logger.telegram)
                    updates = try await telegramServiceForUpdates.getUpdates(offset: nil)
                }
                
                // Фильтруем только сообщения (не редактирования)
                let messages = updates.compactMap { update -> TelegramMessage? in
                    if let message = update.message {
                        return message
                    }
                    return nil
                }
                Logger.debug("[ExtReports] Updates=\(updates.count), Messages=\(messages.count)", log: Logger.telegram)
                
                // Преобразуем сообщения в объекты Post
                var newExternalPosts: [Post] = []
                
                for message in messages {
                    if let post = convertTelegramMessageToPost(message) {
                        newExternalPosts.append(post)
                    }
                }
                
                Logger.debug("[ExtReports] Converted posts: \(newExternalPosts.count)", log: Logger.telegram)
                
                // Предварительно вычисляем следующий lastUpdateId до перехода на MainActor,
                // чтобы не захватывать 'updates' внутри MainActor.run (Swift 6 strict concurrency)
                let nextUpdateId: Int? = {
                    if let lastUpdate = updates.last {
                        return (lastUpdate.updateId ?? 0) + 1
                    } else {
                        return nil
                    }
                }()

                // Обновляем externalPosts на главном потоке
                let finalExternalPosts = newExternalPosts
                await MainActor.run {
                    self.externalPosts = finalExternalPosts
                    self.saveExternalPosts()
                    
                    // Обновляем lastUpdateId (используем предрасчитанное значение)
                    if let nextUpdateId = nextUpdateId {
                        self.lastUpdateId = nextUpdateId
                        self.userDefaultsManager.set(nextUpdateId, forKey: "lastUpdateId")
                    }
                    
                    Logger.info("[ExtReports] Saved external posts total: \(self.externalPosts.count)", log: Logger.telegram)
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
        // В первую очередь очищаем локальное хранилище
        externalPosts.removeAll()
        saveExternalPosts()
        
        // Сбрасываем lastUpdateId для возможности получения новых сообщений
        lastUpdateId = nil
        userDefaultsManager.remove(forKey: "lastUpdateId")
        
        Logger.info("Successfully cleared all external posts and reset update ID", log: Logger.telegram)
        completion(true)
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
    
    // MARK: - Report Formatting
    
    func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String {
        if let telegramService = telegramService as? TelegramService {
            return telegramService.formatCustomReportForTelegram(report, deviceName: deviceName)
        } else {
            // Fallback форматирование если TelegramService недоступен
            var message = "📝 <b>Кастомный отчет за \(DateUtils.formatDate(report.date))</b>\n"
            message += "📱 <i>Устройство: \(deviceName)</i>\n\n"
            
            if !report.goodItems.isEmpty {
                message += "✅ <b>План:</b>\n"
                for (index, item) in report.goodItems.enumerated() {
                    let status = if let evaluationResults = report.evaluationResults,
                                   index < evaluationResults.count {
                        evaluationResults[index] ? "✅" : "❌"
                    } else {
                        "•"
                    }
                    message += "\(status) \(item)\n"
                }
                message += "\n"
            }
            
            if let evaluationResults = report.evaluationResults, !evaluationResults.isEmpty {
                let completed = evaluationResults.filter { $0 }.count
                let total = evaluationResults.count
                let percentage = Int((Double(completed) / Double(total)) * 100)
                message += "\n📊 <b>Результат выполнения:</b> \(completed)/\(total) (\(percentage)%)\n"
            }
            
            return message
        }
    }
}

// MARK: - Typealias for easier usage
typealias TelegramIntegrationServiceType = any TelegramIntegrationServiceProtocol
