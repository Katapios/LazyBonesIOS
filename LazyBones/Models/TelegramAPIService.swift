// TelegramAPIService.swift
// Сервис для работы с Telegram Bot API: получение сообщений, скачивание файлов, lazy loading
import Foundation

struct TelegramMessage {
    let id: Int // message_id
    let updateId: Int // update_id из Telegram
    let date: Date
    let text: String?
    let caption: String? // подпись к медиа
    let authorUsername: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorId: Int? // ID автора сообщения
    let voiceFileId: String?
    let isFromBot: Bool // true, если сообщение от бота
}

class TelegramAPIService {
    private let token: String
    private let chatId: String
    private var lastUpdateId: Int?
    private let session = URLSession.shared
    
    init(token: String, chatId: String) {
        self.token = token
        self.chatId = chatId
    }
    
    // Получить batch сообщений (lazy load)
    func fetchMessages(offset: Int?, limit: Int = 20, botId: String? = nil, completion: @escaping (Result<[TelegramMessage], Error>) -> Void) {
        let urlString = "https://api.telegram.org/bot\(token)/getUpdates?timeout=10\(offset != nil ? "&offset=\(offset!)" : "")"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TelegramAPIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "TelegramAPIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let result = try TelegramAPIService.parseUpdates(data: data, chatId: self.chatId, botId: botId)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // Скачать голосовую заметку по file_id
    func downloadVoice(fileId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // 1. Получить путь к файлу через getFile
        let getFileUrl = "https://api.telegram.org/bot\(token)/getFile?file_id=\(fileId)"
        guard let url = URL(string: getFileUrl) else {
            completion(.failure(NSError(domain: "TelegramAPIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid getFile URL"])))
            return
        }
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let filePath = result["file_path"] as? String else {
                completion(.failure(NSError(domain: "TelegramAPIService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No file_path in response"])))
                return
            }
            // 2. Скачать сам файл
            let fileUrl = "https://api.telegram.org/file/bot\(self.token)/\(filePath)"
            guard let downloadUrl = URL(string: fileUrl) else {
                completion(.failure(NSError(domain: "TelegramAPIService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid file download URL"])))
                return
            }
            let downloadTask = self.session.downloadTask(with: downloadUrl) { localUrl, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let localUrl = localUrl else {
                    completion(.failure(NSError(domain: "TelegramAPIService", code: 6, userInfo: [NSLocalizedDescriptionKey: "No local file url"])))
                    return
                }
                completion(.success(localUrl))
            }
            downloadTask.resume()
        }
        task.resume()
    }
    
    // MARK: - Вспомогательный парсер
    static func parseUpdates(data: Data, chatId: String, botId: String?) throws -> [TelegramMessage] {
        // Простейший парсер для примера (ожидает стандартный ответ Telegram getUpdates)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]] else {
            return []
        }
        var messages: [TelegramMessage] = []
        for update in result {
            let updateId = update["update_id"] as? Int ?? 0
            guard let message = update["message"] as? [String: Any] else { continue }
            
            // Фильтрация по chat_id - только сообщения из нужной группы
            guard let chat = message["chat"] as? [String: Any],
                  let messageChatId = chat["id"] as? Int,
                  String(messageChatId) == chatId else { continue }
            
            let id = message["message_id"] as? Int ?? 0
            let date = (message["date"] as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) } ?? Date()
            let text = message["text"] as? String
            let caption = message["caption"] as? String
            let from = message["from"] as? [String: Any]
            let username = from?["username"] as? String
            let firstName = from?["first_name"] as? String
            let lastName = from?["last_name"] as? String
            let authorId = from?["id"] as? Int
            let voice = message["voice"] as? [String: Any]
            let voiceFileId = voice?["file_id"] as? String
            
            // Определяем, является ли сообщение от бота
            let isFromBot = botId != nil && authorId != nil && String(authorId!) == botId
            
            messages.append(TelegramMessage(
                id: id,
                updateId: updateId,
                date: date, 
                text: text, 
                caption: caption, 
                authorUsername: username, 
                authorFirstName: firstName, 
                authorLastName: lastName, 
                authorId: authorId,
                voiceFileId: voiceFileId,
                isFromBot: isFromBot
            ))
        }
        return messages
    }
}

extension TelegramAPIService {
    func deleteMessages(messageIds: [Int], completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var allSuccess = true
        for messageId in messageIds {
            group.enter()
            let urlString = "https://api.telegram.org/bot\(token)/deleteMessage?chat_id=\(chatId)&message_id=\(messageId)"
            guard let url = URL(string: urlString) else {
                allSuccess = false
                group.leave()
                continue
            }
            let task = session.dataTask(with: url) { data, response, error in
                if error != nil {
                    allSuccess = false
                }
                group.leave()
            }
            task.resume()
        }
        group.notify(queue: .main) {
            completion(allSuccess)
        }
    }
} 