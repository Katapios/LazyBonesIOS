import Foundation

/// Адаптер для конвертации между Legacy Post и Domain Post моделями
/// Обеспечивает плавный переход при миграции на Clean Architecture
struct PostAdapter {
    
    // MARK: - Post -> DomainPost
    
    /// Конвертирует Legacy Post в Domain Post
    static func toDomain(_ post: Post) -> DomainPost {
        return DomainPost(
            id: post.id,
            date: post.date,
            goodItems: post.goodItems,
            badItems: post.badItems,
            published: post.published,
            voiceNotes: post.voiceNotes.map { VoiceNoteAdapter.toDomain($0) },
            type: post.type,
            isEvaluated: post.isEvaluated,
            evaluationResults: post.evaluationResults,
            authorUsername: post.authorUsername,
            authorFirstName: post.authorFirstName,
            authorLastName: post.authorLastName,
            isExternal: post.isExternal,
            externalVoiceNoteURLs: post.externalVoiceNoteURLs,
            externalText: post.externalText,
            externalMessageId: post.externalMessageId,
            authorId: post.authorId
        )
    }
    
    /// Конвертирует массив Legacy Posts в Domain Posts
    static func toDomain(_ posts: [Post]) -> [DomainPost] {
        return posts.map { toDomain($0) }
    }
    
    // MARK: - DomainPost -> Post
    
    /// Конвертирует Domain Post в Legacy Post
    static func toLegacy(_ domainPost: DomainPost) -> Post {
        return Post(
            id: domainPost.id,
            date: domainPost.date,
            goodItems: domainPost.goodItems,
            badItems: domainPost.badItems,
            published: domainPost.published,
            voiceNotes: domainPost.voiceNotes.map { VoiceNoteAdapter.toLegacy($0) },
            type: domainPost.type,
            isEvaluated: domainPost.isEvaluated,
            evaluationResults: domainPost.evaluationResults,
            authorUsername: domainPost.authorUsername,
            authorFirstName: domainPost.authorFirstName,
            authorLastName: domainPost.authorLastName,
            isExternal: domainPost.isExternal,
            externalVoiceNoteURLs: domainPost.externalVoiceNoteURLs,
            externalText: domainPost.externalText,
            externalMessageId: domainPost.externalMessageId,
            authorId: domainPost.authorId
        )
    }
    
    /// Конвертирует массив Domain Posts в Legacy Posts
    static func toLegacy(_ domainPosts: [DomainPost]) -> [Post] {
        return domainPosts.map { toLegacy($0) }
    }
}

/// Адаптер для конвертации голосовых заметок
struct VoiceNoteAdapter {
    
    /// Конвертирует Legacy VoiceNote в Domain VoiceNote
    static func toDomain(_ voiceNote: VoiceNote) -> DomainVoiceNote {
        // Конвертируем path в URL
        let url = URL(fileURLWithPath: voiceNote.path)
        return DomainVoiceNote(
            id: voiceNote.id,
            url: url,
            duration: 0.0 // Legacy VoiceNote не имеет duration
        )
    }
    
    /// Конвертирует Domain VoiceNote в Legacy VoiceNote
    static func toLegacy(_ domainVoiceNote: DomainVoiceNote) -> VoiceNote {
        return VoiceNote(
            id: domainVoiceNote.id,
            path: domainVoiceNote.url.path
        )
    }
}

// MARK: - Extensions для удобства

extension Post {
    /// Конвертирует Legacy Post в Domain Post
    func toDomain() -> DomainPost {
        return PostAdapter.toDomain(self)
    }
}

extension DomainPost {
    /// Конвертирует Domain Post в Legacy Post
    func toLegacy() -> Post {
        return PostAdapter.toLegacy(self)
    }
}

extension Array where Element == Post {
    /// Конвертирует массив Legacy Posts в Domain Posts
    func toDomain() -> [DomainPost] {
        return PostAdapter.toDomain(self)
    }
}

extension Array where Element == DomainPost {
    /// Конвертирует массив Domain Posts в Legacy Posts
    func toLegacy() -> [Post] {
        return PostAdapter.toLegacy(self)
    }
}
