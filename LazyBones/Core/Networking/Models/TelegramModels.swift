import Foundation

// MARK: - Telegram API Models

/// Модель ответа Telegram API
struct TelegramResponse<T: Codable>: Codable {
    let ok: Bool
    let result: T?
    let description: String?
    let errorCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case ok
        case result
        case description
        case errorCode = "error_code"
    }
}

/// Модель сообщения Telegram
struct TelegramMessage: Codable {
    let messageId: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let date: Int
    let text: String?
    let voice: TelegramVoice?
    let audio: TelegramAudio?
    let document: TelegramDocument?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from
        case chat
        case date
        case text
        case voice
        case audio
        case document
    }
}

/// Модель пользователя Telegram
struct TelegramUser: Codable {
    let id: Int
    let isBot: Bool
    let firstName: String
    let lastName: String?
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
    }
}

/// Модель чата Telegram
struct TelegramChat: Codable {
    let id: Int
    let type: String
    let title: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case username
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

/// Модель голосового сообщения Telegram
struct TelegramVoice: Codable {
    let fileId: String
    let fileUniqueId: String
    let duration: Int
    let mimeType: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case duration
        case mimeType = "mime_type"
        case fileSize = "file_size"
    }
}

/// Модель аудио файла Telegram
struct TelegramAudio: Codable {
    let fileId: String
    let fileUniqueId: String
    let duration: Int
    let performer: String?
    let title: String?
    let mimeType: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case duration
        case performer
        case title
        case mimeType = "mime_type"
        case fileSize = "file_size"
    }
}

/// Модель документа Telegram
struct TelegramDocument: Codable {
    let fileId: String
    let fileUniqueId: String
    let fileName: String?
    let mimeType: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSize = "file_size"
    }
}

/// Модель файла Telegram
struct TelegramFile: Codable {
    let fileId: String
    let fileUniqueId: String
    let fileSize: Int?
    let filePath: String?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileSize = "file_size"
        case filePath = "file_path"
    }
}

/// Модель обновления Telegram
struct TelegramUpdate: Codable {
    let updateId: Int
    let message: TelegramMessage?
    let editedMessage: TelegramMessage?
    let channelPost: TelegramMessage?
    let editedChannelPost: TelegramMessage?
    
    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
        case editedMessage = "edited_message"
        case channelPost = "channel_post"
        case editedChannelPost = "edited_channel_post"
    }
}

/// Модель для отправки сообщения
struct SendMessageRequest: Codable {
    let chatId: String
    let text: String
    let parseMode: String?
    let disableWebPagePreview: Bool?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case parseMode = "parse_mode"
        case disableWebPagePreview = "disable_web_page_preview"
    }
}

/// Модель для отправки файла
struct SendDocumentRequest: Codable {
    let chatId: String
    let document: String // file_id или URL
    let caption: String?
    let parseMode: String?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case document
        case caption
        case parseMode = "parse_mode"
    }
}

/// Модель для отправки голосового сообщения
struct SendVoiceRequest: Codable {
    let chatId: String
    let voice: String // file_id или URL
    let caption: String?
    let parseMode: String?
    let duration: Int?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case voice
        case caption
        case parseMode = "parse_mode"
        case duration
    }
} 