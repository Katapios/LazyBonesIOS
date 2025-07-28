import Foundation

/// Протокол сервиса Telegram
protocol TelegramServiceProtocol {
    func sendMessage(_ text: String, to chatId: String) async throws
    func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws
    func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws
    func getUpdates(offset: Int?) async throws -> [TelegramUpdate]
    func getMe() async throws -> TelegramUser
    func downloadFile(_ fileId: String) async throws -> Data
}

/// Ошибки Telegram сервиса
enum TelegramServiceError: Error, LocalizedError {
    case invalidToken
    case invalidChatId
    case networkError(Error)
    case apiError(String)
    case fileNotFound
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid Telegram bot token"
        case .invalidChatId:
            return "Invalid chat ID"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "Telegram API error: \(message)"
        case .fileNotFound:
            return "File not found"
        case .downloadFailed:
            return "Failed to download file"
        }
    }
}

/// Реализация сервиса Telegram
class TelegramService: TelegramServiceProtocol {
    
    private let apiClient: APIClient
    private let token: String
    private let baseURL: String
    
    init(token: String) {
        self.token = token
        self.baseURL = "https://api.telegram.org/bot\(token)"
        self.apiClient = APIClient(baseURL: baseURL)
    }
    
    // MARK: - TelegramServiceProtocol
    
    func sendMessage(_ text: String, to chatId: String) async throws {
        Logger.debug("Sending message to chat: \(chatId)", log: Logger.networking)
        
        let request = SendMessageRequest(
            chatId: chatId,
            text: text,
            parseMode: "HTML",
            disableWebPagePreview: true
        )
        
        do {
            let response: TelegramResponse<TelegramMessage> = try await apiClient.post(
                "sendMessage",
                body: try JSONEncoder().encode(request)
            )
            
            if response.ok {
                Logger.info("Message sent successfully", log: Logger.networking)
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to send message: \(error)", log: Logger.networking)
            throw TelegramServiceError.networkError(error)
        }
    }
    
    func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws {
        Logger.debug("Sending document to chat: \(chatId)", log: Logger.networking)
        
        let parameters: [String: Any] = [
            "chat_id": chatId,
            "caption": caption ?? "",
            "parse_mode": "HTML"
        ]
        
        do {
            let response: TelegramResponse<TelegramMessage> = try await apiClient.upload(
                "sendDocument",
                fileURL: fileURL,
                fieldName: "document",
                parameters: parameters
            )
            
            if response.ok {
                Logger.info("Document sent successfully", log: Logger.networking)
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to send document: \(error)", log: Logger.networking)
            throw TelegramServiceError.networkError(error)
        }
    }
    
    func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws {
        Logger.debug("Sending voice to chat: \(chatId)", log: Logger.networking)
        
        let parameters: [String: Any] = [
            "chat_id": chatId,
            "caption": caption ?? "",
            "parse_mode": "HTML"
        ]
        
        do {
            let response: TelegramResponse<TelegramMessage> = try await apiClient.upload(
                "sendVoice",
                fileURL: fileURL,
                fieldName: "voice",
                parameters: parameters
            )
            
            if response.ok {
                Logger.info("Voice sent successfully", log: Logger.networking)
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to send voice: \(error)", log: Logger.networking)
            throw TelegramServiceError.networkError(error)
        }
    }
    
    func getUpdates(offset: Int? = nil) async throws -> [TelegramUpdate] {
        Logger.debug("Getting updates with offset: \(offset ?? 0)", log: Logger.networking)
        
        var parameters: [String: Any] = [:]
        if let offset = offset {
            parameters["offset"] = offset
        }
        
        do {
            let response: TelegramResponse<[TelegramUpdate]> = try await apiClient.get(
                "getUpdates",
                parameters: parameters
            )
            
            if response.ok {
                let updates = response.result ?? []
                Logger.info("Received \(updates.count) updates", log: Logger.networking)
                return updates
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to get updates: \(error)", log: Logger.networking)
            throw TelegramServiceError.networkError(error)
        }
    }
    
    func getMe() async throws -> TelegramUser {
        Logger.debug("Getting bot info", log: Logger.networking)
        
        do {
            let response: TelegramResponse<TelegramUser> = try await apiClient.get("getMe")
            
            if response.ok, let user = response.result {
                Logger.info("Bot info received: \(user.firstName)", log: Logger.networking)
                return user
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to get bot info: \(error)", log: Logger.networking)
            throw TelegramServiceError.networkError(error)
        }
    }
    
    func downloadFile(_ fileId: String) async throws -> Data {
        Logger.debug("Downloading file with ID: \(fileId)", log: Logger.networking)
        
        // Сначала получаем информацию о файле
        let fileInfo: TelegramResponse<TelegramFile> = try await apiClient.get(
            "getFile",
            parameters: ["file_id": fileId]
        )
        
        guard fileInfo.ok, let file = fileInfo.result, let filePath = file.filePath else {
            throw TelegramServiceError.fileNotFound
        }
        
        // Скачиваем файл
        let fileURL = "https://api.telegram.org/file/bot\(token)/\(filePath)"
        
        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: fileURL)!)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TelegramServiceError.downloadFailed
            }
            
            Logger.info("File downloaded successfully, size: \(data.count) bytes", log: Logger.networking)
            return data
        } catch {
            Logger.error("Failed to download file: \(error)", log: Logger.networking)
            throw TelegramServiceError.downloadFailed
        }
    }
    
    // MARK: - Helper Methods
    
    /// Форматировать отчет для отправки в Telegram
    func formatReportForTelegram(_ report: Report, deviceName: String) -> String {
        var message = "📊 <b>Отчет за \(DateUtils.formatDate(report.date))</b>\n"
        message += "📱 <i>Устройство: \(deviceName)</i>\n\n"
        
        if !report.goodItems.isEmpty {
            message += "✅ <b>Хорошее:</b>\n"
            for item in report.goodItems {
                message += "• \(item)\n"
            }
            message += "\n"
        }
        
        if !report.badItems.isEmpty {
            message += "❌ <b>Плохое:</b>\n"
            for item in report.badItems {
                message += "• \(item)\n"
            }
            message += "\n"
        }
        
        if !report.voiceNotes.isEmpty {
            message += "🎤 <b>Голосовые заметки:</b> \(report.voiceNotes.count)\n"
        }
        
        if report.type == .custom {
            message += "📝 <b>Тип:</b> Кастомный отчет\n"
        }
        
        return message
    }
    
    /// Проверить валидность токена
    func validateToken() async throws -> Bool {
        do {
            _ = try await getMe()
            return true
        } catch {
            return false
        }
    }
} 