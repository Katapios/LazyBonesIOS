import Foundation

protocol PublishRegularReportUseCaseProtocol {
    func execute(_ draft: RegularReportDraft, completion: @escaping (Bool) -> Void)
}

/// Заглушка UC: публикация обычного отчёта (создание/обновление Post.published=true + отправка в Telegram)
final class PublishRegularReportUseCase: PublishRegularReportUseCaseProtocol {
    private let postsProvider: PostsProviderProtocol
    private let postStore: PostStore
    
    init(postsProvider: PostsProviderProtocol, postStore: PostStore) {
        self.postsProvider = postsProvider
        self.postStore = postStore
    }
    
    func execute(_ draft: RegularReportDraft, completion: @escaping (Bool) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let posts = postsProvider.getPosts()
        let existingToday = posts.first { $0.type == .regular && calendar.isDate($0.date, inSameDayAs: today) }
        
        // Фильтруем пустые/пробельные элементы
        let good = draft.good.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let bad = draft.bad.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        // Сформируем Post (как в легаси — до отправки published=false)
        var post = Post(
            id: existingToday?.id ?? UUID(),
            date: existingToday?.date ?? Date(),
            goodItems: good,
            badItems: bad,
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
        
        // Сохраняем в PostStore: обновление если есть, иначе добавление
        if existingToday != nil {
            postStore.update(post: post)
        } else {
            postStore.add(post: post)
        }
        
        // Формируем текст 1:1 с DailyReportView (HTML + ru_RU + нумерация)
        let deviceName = postStore.getDeviceName()
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .full
        let dateStr = df.string(from: post.date)
        var text = "\u{1F4C5} <b>Отчет за день - \(dateStr)</b>\n"
        text += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !post.goodItems.isEmpty {
            text += "<b>✅ Я молодец:</b>\n"
            for (i, item) in post.goodItems.enumerated() { text += "\(i + 1). \(item)\n" }
            text += "\n"
        }
        if !post.badItems.isEmpty {
            text += "<b>❌ Я не молодец:</b>\n"
            for (i, item) in post.badItems.enumerated() { text += "\(i + 1). \(item)\n" }
        }
        
        // Подготовим пути к голосовым (проверка существования выполняется внутри PostStore.publish)
        let voicePaths = post.voiceNotes.map { $0.path }
        
        // Публикуем: сначала текст, затем (если есть) валидные голосовые
        let validVoicePaths = voicePaths.filter { FileManager.default.fileExists(atPath: $0) }
        if !validVoicePaths.isEmpty {
            text += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
        }
        postStore.publish(text: text, voicePaths: validVoicePaths) { [weak self] success in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async {
                if success {
                    // Помечаем пост как опубликованный и сохраняем
                    post.published = true
                    self.postStore.update(post: post)
                    self.postStore.save()
                    // Обновляем статус модели отчётов
                    self.postStore.updateReportStatus()
                }
                completion(success)
            }
        }
    }
}
