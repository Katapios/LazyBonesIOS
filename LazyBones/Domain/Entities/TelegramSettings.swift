import Foundation

public struct TelegramSettings: Equatable {
    public var token: String?
    public var chatId: String?
    public var botId: String?
    public var lastUpdateId: Int?
    
    public init(token: String?, chatId: String?, botId: String?, lastUpdateId: Int?) {
        self.token = token
        self.chatId = chatId
        self.botId = botId
        self.lastUpdateId = lastUpdateId
    }
}
