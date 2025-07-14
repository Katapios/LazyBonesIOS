import Foundation

class TelegramService {
    private let api: TelegramAPIService
    init(token: String, chatId: String) {
        self.api = TelegramAPIService(token: token, chatId: chatId)
    }
    
    func fetchMessages(offset: Int?, limit: Int = 20, botId: String? = nil, completion: @escaping (Result<[TelegramMessage], Error>) -> Void) {
        api.fetchMessages(offset: offset, limit: limit, botId: botId, completion: completion)
    }
    
    func downloadVoice(fileId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        api.downloadVoice(fileId: fileId, completion: completion)
    }
    
    func deleteMessages(messageIds: [Int], completion: @escaping (Bool) -> Void) {
        api.deleteMessages(messageIds: messageIds, completion: completion)
    }
} 