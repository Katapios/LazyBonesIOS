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
        
        // Используем специальный метод для сохранения настроек Telegram
        userDefaultsManager.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        
        // Обновляем TelegramService в DI контейнере только если есть валидный токен
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
        
        Logger.info("Telegram token found: \(String(token.prefix(10)))...", log: Logger.telegram)
        Logger.info("Last update ID: \(lastUpdateId ?? 0)", log: Logger.telegram)
        
        Task {
            do {
                // Получаем TelegramService для обновлений
                guard let telegramServiceForUpdates = telegramService else {
                    Logger.error("TelegramService not available", log: Logger.telegram)
                    Logger.error("telegramService is nil", log: Logger.telegram)
                    completion(false)
                    return
                }
                
                Logger.info("TelegramService is available", log: Logger.telegram)
                
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
                
                // Добавляем новые сообщения к существующим на главном потоке
                let postsToAdd = newExternalPosts // Создаем копию для использования в MainActor
                await MainActor.run {
                    // Добавляем новые сообщения к существующим
                    self.externalPosts.append(contentsOf: postsToAdd)
                    
                    // Удаляем дубликаты по messageId
                    let uniquePosts = self.removeDuplicatePosts(self.externalPosts)
                    self.externalPosts = uniquePosts
                    
                    self.saveExternalPosts()
                    
                    // Обновляем lastUpdateId
                    if let lastUpdate = updates.last {
                        self.lastUpdateId = (lastUpdate.updateId ?? 0) + 1
                        self.userDefaultsManager.set(self.lastUpdateId, forKey: "lastUpdateId")
                    }
                    
                    Logger.info("Added \(postsToAdd.count) new external posts, total: \(self.externalPosts.count)", log: Logger.telegram)
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
        Logger.info("Clearing all external posts history", log: Logger.telegram)
        
        // Очищаем все внешние сообщения
        externalPosts.removeAll()
        
        // Сохраняем пустой список
        saveExternalPosts()
        
        // Сбрасываем lastUpdateId для получения всех сообщений заново
        lastUpdateId = 0
        userDefaultsManager.set(0, forKey: "lastUpdateId")
        
        Logger.info("Successfully cleared all external posts history", log: Logger.telegram)
        completion(true)
    }
    
    // MARK: - Message Conversion
    
    func convertTelegramMessageToPost(_ message: TelegramMessage) -> Post? {
        // Если есть текст — обычный текстовый отчет
        if let text = message.text, !text.isEmpty {
            // Парсим текст для извлечения структурированных данных
            let (goodItems, badItems, remainingText) = parseReportText(text)
            
            let post = Post(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(message.date ?? 0)),
                goodItems: goodItems,
                badItems: badItems,
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
                externalText: remainingText.isEmpty ? nil : remainingText,
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
    
    // MARK: - Text Parsing
    
    /// Парсит текст отчета для извлечения структурированных данных
    private func parseReportText(_ text: String) -> (goodItems: [String], badItems: [String], remainingText: String) {
        var goodItems: [String] = []
        var badItems: [String] = []
        var remainingText = text
        
        // Паттерны для поиска секций
        let goodPatterns = [
            "я молодец:",
            "я молодец",
            "молодец:",
            "молодец",
            "хорошо:",
            "хорошо",
            "плюсы:",
            "плюсы",
            "+:",
            "+"
        ]
        
        let badPatterns = [
            "я не молодец:",
            "я не молодец",
            "не молодец:",
            "не молодец",
            "плохо:",
            "плохо",
            "минусы:",
            "минусы",
            "-:",
            "-"
        ]
        
        // Разбиваем текст на строки
        let lines = text.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var currentItems: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            // Проверяем, является ли строка заголовком секции
            let lowercasedLine = trimmedLine.lowercased()
            
            if goodPatterns.contains(where: { lowercasedLine.contains($0) }) {
                // Сохраняем предыдущую секцию
                if let section = currentSection, !currentItems.isEmpty {
                    if section == "good" {
                        goodItems.append(contentsOf: currentItems)
                    } else if section == "bad" {
                        badItems.append(contentsOf: currentItems)
                    }
                }
                
                // Начинаем новую секцию
                currentSection = "good"
                currentItems = []
                continue
            }
            
            if badPatterns.contains(where: { lowercasedLine.contains($0) }) {
                // Сохраняем предыдущую секцию
                if let section = currentSection, !currentItems.isEmpty {
                    if section == "good" {
                        goodItems.append(contentsOf: currentItems)
                    } else if section == "bad" {
                        badItems.append(contentsOf: currentItems)
                    }
                }
                
                // Начинаем новую секцию
                currentSection = "bad"
                currentItems = []
                continue
            }
            
            // Если это не заголовок, добавляем в текущую секцию
            if currentSection != nil {
                // Убираем номера и маркеры в начале строки
                let cleanedItem = trimmedLine.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                
                if !cleanedItem.isEmpty {
                    currentItems.append(cleanedItem)
                }
            }
        }
        
        // Сохраняем последнюю секцию
        if let section = currentSection, !currentItems.isEmpty {
            if section == "good" {
                goodItems.append(contentsOf: currentItems)
            } else if section == "bad" {
                badItems.append(contentsOf: currentItems)
            }
        }
        
        // Убираем обработанные секции из оставшегося текста
        var processedText = text
        for pattern in goodPatterns + badPatterns {
            processedText = processedText.replacingOccurrences(of: pattern, with: "", options: [.caseInsensitive, .regularExpression])
        }
        
        // Убираем пустые строки и лишние пробелы
        remainingText = processedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (goodItems: goodItems, badItems: badItems, remainingText: remainingText)
    }
    
    // MARK: - Utility Methods
    
    /// Удаляет дубликаты постов по externalMessageId
    private func removeDuplicatePosts(_ posts: [Post]) -> [Post] {
        var seenMessageIds: Set<Int> = []
        var uniquePosts: [Post] = []
        
        for post in posts {
            if let messageId = post.externalMessageId {
                if !seenMessageIds.contains(messageId) {
                    seenMessageIds.insert(messageId)
                    uniquePosts.append(post)
                }
            } else {
                // Если нет messageId, добавляем пост (может быть локальным)
                uniquePosts.append(post)
            }
        }
        
        return uniquePosts
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