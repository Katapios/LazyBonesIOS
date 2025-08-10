import Foundation
import SwiftUI
import WidgetKit

/// ViewModel-адаптер для PostFormView, который оборачивает PostStore
/// Управляет созданием и редактированием отчетов с поддержкой голосовых заметок
@MainActor
class PostFormViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var store: PostStore
    @Published var goodItems: [ChecklistItem]
    @Published var badItems: [ChecklistItem]
    @Published var voiceNotes: [VoiceNote]
    @Published var isSending: Bool = false
    @Published var sendStatus: String? = nil
    @Published var selectedTab: TabType = .good
    @Published var pickerIndexGood: Int = 0
    @Published var pickerIndexBad: Int = 0
    
    // MARK: - Properties
    let title: String
    let post: Post?
    let onSave: (() -> Void)?
    let onPublish: (() -> Void)?
    
    enum TabType { case good, bad }
    
    // MARK: - Initialization
    init(
        store: PostStore,
        title: String = "Создать отчёт",
        post: Post? = nil,
        onSave: (() -> Void)? = nil,
        onPublish: (() -> Void)? = nil
    ) {
        self.store = store
        self.title = title
        self.post = post
        self.onSave = onSave
        self.onPublish = onPublish
        
        if let post = post {
            self.goodItems = post.goodItems.map {
                ChecklistItem(id: UUID(), text: $0)
            }
            self.badItems = post.badItems.map {
                ChecklistItem(id: UUID(), text: $0)
            }
            self.voiceNotes = post.voiceNotes
        } else {
            self.goodItems = [ChecklistItem(id: UUID(), text: "")]
            self.badItems = [ChecklistItem(id: UUID(), text: "")]
            self.voiceNotes = []
        }
    }
    
    // MARK: - Computed Properties
    var goodTags: [TagItem] {
        store.goodTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    var badTags: [TagItem] {
        store.badTags.map { TagItem(text: $0, icon: "tag", color: .red) }
    }
    
    var isReportDone: Bool {
        store.reportStatus == .sent
    }
    
    // MARK: - Methods
    
    /// Добавить хороший пункт
    func addGoodItem() {
        goodItems.append(ChecklistItem(id: UUID(), text: ""))
    }
    
    /// Добавить хороший тег
    func addGoodTag(_ tag: TagItem) {
        let text = getIconForItem(tag.text, isGood: true)
        if let lastItem = goodItems.last, lastItem.text.isEmpty {
            goodItems[goodItems.count - 1] = ChecklistItem(id: lastItem.id, text: text)
        } else {
            goodItems.append(ChecklistItem(id: UUID(), text: text))
        }
    }
    
    /// Добавить плохой тег
    func addBadTag(_ tag: TagItem) {
        let text = getIconForItem(tag.text, isGood: false)
        if let lastItem = badItems.last, lastItem.text.isEmpty {
            badItems[badItems.count - 1] = ChecklistItem(id: lastItem.id, text: text)
        } else {
            badItems.append(ChecklistItem(id: UUID(), text: text))
        }
    }
    
    /// Удалить хороший пункт
    func removeGoodItem(_ item: ChecklistItem) {
        goodItems.removeAll { $0.id == item.id }
        if goodItems.isEmpty {
            goodItems.append(ChecklistItem(id: UUID(), text: ""))
        }
    }
    
    /// Добавить плохой пункт
    func addBadItem() {
        badItems.append(ChecklistItem(id: UUID(), text: ""))
    }
    
    /// Удалить плохой пункт
    func removeBadItem(_ item: ChecklistItem) {
        badItems.removeAll { $0.id == item.id }
        if badItems.isEmpty {
            badItems.append(ChecklistItem(id: UUID(), text: ""))
        }
    }
    
    /// Сохранить и уведомить
    func saveAndNotify() {
        let goodTexts = goodItems.compactMap { item in
            let trimmed = item.text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        let badTexts = badItems.compactMap { item in
            let trimmed = item.text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        let newPost = Post(
            id: post?.id ?? UUID(),
            date: post?.date ?? Date(),
            goodItems: goodTexts,
            badItems: badTexts,
            published: post?.published ?? false,
            voiceNotes: voiceNotes,
            type: post?.type ?? .regular
        )
        
        if post != nil {
            store.update(post: newPost)
        } else {
            store.add(post: newPost)
        }
        
        onSave?()
        objectWillChange.send()
    }
    
    /// Опубликовать и уведомить
    func publishAndNotify() {
        let goodTexts = goodItems.compactMap { item in
            let trimmed = item.text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        let badTexts = badItems.compactMap { item in
            let trimmed = item.text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        let newPost = Post(
            id: post?.id ?? UUID(),
            date: post?.date ?? Date(),
            goodItems: goodTexts,
            badItems: badTexts,
            published: true,
            voiceNotes: voiceNotes,
            type: post?.type ?? .regular
        )
        
        if post != nil {
            store.update(post: newPost)
        } else {
            store.add(post: newPost)
        }
        
        // Отправляем через новую архитектуру
        isSending = true
        sendStatus = "Отправка в Telegram..."
        Task { @MainActor in
            guard
                let getUC = DependencyContainer.shared.resolve(GetReportsUseCase.self),
                let delUC = DependencyContainer.shared.resolve(DeleteReportUseCase.self),
                let updUC = DependencyContainer.shared.resolve(UpdateReportUseCase.self),
                let tagRepo = DependencyContainer.shared.resolve((any TagRepositoryProtocol).self),
                let postTg = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self)
            else {
                self.isSending = false
                self.sendStatus = "Ошибка DI: зависимости не найдены"
                return
            }

            let vm = ReportsViewModelNew(
                getReportsUseCase: getUC,
                deleteReportUseCase: delUC,
                updateReportUseCase: updUC,
                tagRepository: tagRepo,
                postTelegramService: postTg
            )

            let domainPost = PostAdapter.toDomain(newPost)
            await vm.handle(.sendRegularReport(domainPost))

            if vm.state.error == nil {
                self.sendStatus = "Отправлено успешно!"
                self.onPublish?()
            } else {
                self.sendStatus = "Ошибка отправки"
            }
            self.isSending = false
            self.objectWillChange.send()
        }
    }
    
    /// Получить иконку для элемента
    private func getIconForItem(_ item: String, isGood: Bool) -> String {
        let icon = isGood ? "✅" : "❌"
        return "\(icon) \(item)"
    }
}

// MARK: - Supporting Types
struct TagItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let icon: String
    let color: Color

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TagItem, rhs: TagItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChecklistItem: Identifiable, Equatable {
    let id: UUID
    var text: String
} 