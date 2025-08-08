import Foundation

/// Настройки интеграции с Telegram
public struct TelegramSettings: Equatable, Codable {
    /// Токен бота
    public let token: String
    /// ID чата
    public let chatId: String
    /// ID бота (опционально)
    public let botId: String?
    
    public init(token: String = "", chatId: String = "", botId: String? = nil) {
        self.token = token
        self.chatId = chatId
        self.botId = botId
    }
    
    /// Проверяет, заполнены ли обязательные поля
    public var isValid: Bool {
        !token.isEmpty && !chatId.isEmpty
    }
}
