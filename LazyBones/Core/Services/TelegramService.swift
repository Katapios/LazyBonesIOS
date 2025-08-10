import Foundation

// Импорты для работы с моделями

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
            if let tgError = error as? TelegramServiceError {
                throw tgError
            } else {
                throw TelegramServiceError.networkError(error)
            }
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
            if let tgError = error as? TelegramServiceError {
                throw tgError
            } else {
                throw TelegramServiceError.networkError(error)
            }
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
            if let tgError = error as? TelegramServiceError {
                throw tgError
            } else {
                throw TelegramServiceError.networkError(error)
            }
        }
    }
    
    func getUpdates(offset: Int? = nil) async throws -> [TelegramUpdate] {
        Logger.debug("Getting updates with offset: \(offset ?? 0)", log: Logger.networking)
        Logger.info("TelegramService.getUpdates called with token: \(String(token.prefix(10)))...", log: Logger.networking)
        
        var parameters: [String: Any] = [:]
        if let offset = offset {
            parameters["offset"] = offset
            Logger.info("Using offset parameter: \(offset)", log: Logger.networking)
        } else {
            Logger.info("No offset parameter - will get all available updates", log: Logger.networking)
        }
        
        do {
            let response: TelegramResponse<[TelegramUpdate]> = try await apiClient.get(
                "getUpdates",
                parameters: parameters
            )
            
            Logger.info("Telegram API response received", log: Logger.networking)
            Logger.info("Response ok: \(response.ok)", log: Logger.networking)
            if let description = response.description {
                Logger.info("Response description: \(description)", log: Logger.networking)
            }
            
            if response.ok {
                let updates = response.result // result теперь не опциональный
                Logger.info("Received \(updates.count) updates", log: Logger.networking)
                
                // Логируем детали каждого обновления
                for (index, update) in updates.enumerated() {
                    Logger.debug("Update \(index): id=\(update.updateId ?? 0), hasMessage=\(update.message != nil)", log: Logger.networking)
                }
                
                return updates
            } else {
                Logger.error("Telegram API error: \(response.description ?? "Unknown error")", log: Logger.networking)
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to get updates: \(error)", log: Logger.networking)
            Logger.error("Error type: \(type(of: error))", log: Logger.networking)
            if let tgError = error as? TelegramServiceError {
                throw tgError
            } else {
                throw TelegramServiceError.networkError(error)
            }
        }
    }
    
    func getMe() async throws -> TelegramUser {
        Logger.debug("Getting bot info", log: Logger.networking)
        
        do {
            let response: TelegramResponse<TelegramUser> = try await apiClient.get("getMe")
            
            if response.ok {
                let user = response.result // result теперь не опциональный
                Logger.info("Bot info received: \(user.firstName ?? "Unknown")", log: Logger.networking)
                return user
            } else {
                throw TelegramServiceError.apiError(response.description ?? "Unknown error")
            }
        } catch {
            Logger.error("Failed to get bot info: \(error)", log: Logger.networking)
            if let tgError = error as? TelegramServiceError {
                throw tgError
            } else {
                throw TelegramServiceError.networkError(error)
            }
        }
    }
    
    func downloadFile(_ fileId: String) async throws -> Data {
        Logger.debug("Downloading file with ID: \(fileId)", log: Logger.networking)
        
        // Сначала получаем информацию о файле
        let fileInfo: TelegramResponse<TelegramFile> = try await apiClient.get(
            "getFile",
            parameters: ["file_id": fileId]
        )
        
        guard fileInfo.ok, let filePath = fileInfo.result.filePath else {
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
    
    /// Форматировать обычный отчет для отправки в Telegram
    func formatRegularReportForTelegram(_ report: Post, deviceName: String) -> String {
        var message = "📊 <b>Обычный отчет за \(DateUtils.formatDate(report.date))</b>\n"
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
        
        return message
    }
    
    /// Форматировать кастомный отчет для отправки в Telegram
    func formatCustomReportForTelegram(_ report: Post, deviceName: String) -> String {
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
        
        // Добавляем общую статистику оценки
        if let evaluationResults = report.evaluationResults, !evaluationResults.isEmpty {
            let completed = evaluationResults.filter { $0 }.count
            let total = evaluationResults.count
            let percentage = Int((Double(completed) / Double(total)) * 100)
            message += "\n📊 <b>Результат выполнения:</b> \(completed)/\(total) (\(percentage)%)\n"
        }
        
        return message
    }
    
    /// Форматировать отчет для отправки в Telegram (устаревший метод)
    func formatReportForTelegram(_ report: Post, deviceName: String) -> String {
        return formatRegularReportForTelegram(report, deviceName: deviceName)
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