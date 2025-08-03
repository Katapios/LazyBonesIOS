import Foundation

/// Domain Entity - Голосовая заметка
struct DomainVoiceNote: Codable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        url: URL,
        duration: TimeInterval,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.createdAt = createdAt
    }
} 