import Foundation

/// Маппер для преобразования голосовых заметок
struct VoiceNoteMapper {
    
    /// Преобразование DomainVoiceNote в VoiceNote
    static func toDataModel(_ domainVoiceNote: DomainVoiceNote) -> VoiceNote {
        return VoiceNote(
            id: domainVoiceNote.id,
            path: domainVoiceNote.url.path
        )
    }
    
    /// Преобразование VoiceNote в DomainVoiceNote
    static func toDomainModel(_ voiceNote: VoiceNote) -> DomainVoiceNote {
        let url = URL(fileURLWithPath: voiceNote.path)
        return DomainVoiceNote(
            id: voiceNote.id,
            url: url,
            duration: 0.0, // По умолчанию, так как в старой модели нет duration
            createdAt: Date() // По умолчанию, так как в старой модели нет createdAt
        )
    }
} 