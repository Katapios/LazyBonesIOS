import Foundation

/// Domain Entity - Отчет пользователя
struct DomainPost: Codable, Identifiable {
    let id: UUID
    let date: Date
    var goodItems: [String]
    var badItems: [String]
    var published: Bool
    var voiceNotes: [DomainVoiceNote]
    var type: PostType
    var isEvaluated: Bool?
    var evaluationResults: [Bool]?
    
    // Telegram integration fields
    var authorUsername: String?
    var authorFirstName: String?
    var authorLastName: String?
    var isExternal: Bool?
    var externalVoiceNoteURLs: [URL]?
    var externalText: String?
    var externalMessageId: Int?
    var authorId: Int?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        goodItems: [String] = [],
        badItems: [String] = [],
        published: Bool = false,
        voiceNotes: [DomainVoiceNote] = [],
        type: PostType = .regular,
        isEvaluated: Bool? = nil,
        evaluationResults: [Bool]? = nil,
        authorUsername: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        isExternal: Bool? = nil,
        externalVoiceNoteURLs: [URL]? = nil,
        externalText: String? = nil,
        externalMessageId: Int? = nil,
        authorId: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.goodItems = goodItems
        self.badItems = badItems
        self.published = published
        self.voiceNotes = voiceNotes
        self.type = type
        self.isEvaluated = isEvaluated
        self.evaluationResults = evaluationResults
        self.authorUsername = authorUsername
        self.authorFirstName = authorFirstName
        self.authorLastName = authorLastName
        self.isExternal = isExternal
        self.externalVoiceNoteURLs = externalVoiceNoteURLs
        self.externalText = externalText
        self.externalMessageId = externalMessageId
        self.authorId = authorId
    }
}

/// Тип отчета
enum PostType: String, Codable, CaseIterable {
    case regular // обычный отчет
    case custom // кастомный отчет (план/теги)
    case external // внешний отчет из Telegram
    case iCloud // отчет из iCloud
} 