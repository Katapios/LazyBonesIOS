import Foundation

protocol SaveRegularReportAsLocalUseCaseProtocol {
    func execute(_ draft: RegularReportDraft)
}

/// Сохранить обычный отчет ЛОКАЛЬНО (без публикации), 1:1 с легаси saveAsReport()
final class SaveRegularReportAsLocalUseCase: SaveRegularReportAsLocalUseCaseProtocol {
    private let postsProvider: PostsProviderProtocol
    private let postStore: PostStore
    
    init(postsProvider: PostsProviderProtocol, postStore: PostStore) {
        self.postsProvider = postsProvider
        self.postStore = postStore
    }
    
    func execute(_ draft: RegularReportDraft) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let posts = postsProvider.getPosts()
        let filteredGood = draft.good.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let filteredBad = draft.bad.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        if let idx = posts.firstIndex(where: { $0.type == .regular && calendar.isDate($0.date, inSameDayAs: today) }) {
            // Обновление существующего поста за сегодня — пересобираем Post без изменения let-свойств
            let existing = posts[idx]
            let updated = Post(
                id: existing.id,
                date: existing.date, // сохраняем исходную дату дня
                goodItems: filteredGood,
                badItems: filteredBad,
                published: false,
                voiceNotes: draft.voiceNotes,
                type: .regular,
                isEvaluated: existing.isEvaluated,
                evaluationResults: existing.evaluationResults,
                authorUsername: existing.authorUsername,
                authorFirstName: existing.authorFirstName,
                authorLastName: existing.authorLastName,
                isExternal: existing.isExternal,
                externalVoiceNoteURLs: existing.externalVoiceNoteURLs,
                externalText: existing.externalText,
                externalMessageId: existing.externalMessageId,
                authorId: existing.authorId
            )
            postStore.update(post: updated)
        } else {
            // Создание нового поста за сегодня
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: filteredGood,
                badItems: filteredBad,
                published: false,
                voiceNotes: draft.voiceNotes,
                type: .regular,
                isEvaluated: nil,
                evaluationResults: nil,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: nil,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            postStore.add(post: post)
        }
        postStore.save()
        postStore.updateReportStatus()
    }
}
