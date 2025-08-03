import Foundation

/// Маппер для преобразования между Domain и Data моделями
struct PostMapper {
    
    /// Преобразование DomainPost в Post
    static func toDataModel(_ domainPost: DomainPost) -> Post {
        return Post(
            id: domainPost.id,
            date: domainPost.date,
            goodItems: domainPost.goodItems,
            badItems: domainPost.badItems,
            published: domainPost.published,
            voiceNotes: domainPost.voiceNotes.map { VoiceNoteMapper.toDataModel($0) },
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
    
    /// Преобразование Post в DomainPost
    static func toDomainModel(_ post: Post) -> DomainPost {
        return DomainPost(
            id: post.id,
            date: post.date,
            goodItems: post.goodItems,
            badItems: post.badItems,
            published: post.published,
            voiceNotes: post.voiceNotes.map { VoiceNoteMapper.toDomainModel($0) },
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
    
    /// Преобразование массива Post в массив DomainPost
    static func toDomainModels(_ posts: [Post]) -> [DomainPost] {
        return posts.map { toDomainModel($0) }
    }
    
    /// Преобразование массива DomainPost в массив Post
    static func toDataModels(_ domainPosts: [DomainPost]) -> [Post] {
        return domainPosts.map { toDataModel($0) }
    }
} 