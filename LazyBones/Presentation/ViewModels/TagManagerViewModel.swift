import Foundation
import SwiftUI
import Combine

/// ViewModel-адаптер для TagManagerView, который оборачивает PostStore
/// Управляет тегами (хорошие и плохие) с возможностью добавления, редактирования и удаления
@available(*, deprecated, message: "Legacy VM: используйте TagProvider/TagRepository в новых экранах")
@MainActor
class TagManagerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var store: PostStore
    @Published var tagCategory: Int = 0 // 0 — good, 1 — bad
    @Published var newTag: String = ""
    @Published var editingTagIndex: Int? = nil
    @Published var editingTagText: String = ""
    @Published var showDeleteTagAlert = false
    @Published var tagToDelete: String? = nil
    
    // MARK: - Subscriptions
    private var storeCancellable: AnyCancellable?
    
    // MARK: - Dependencies
    private let tagProvider: TagProviderProtocol? = DependencyContainer.shared.resolve(TagProviderProtocol.self)
    
    // MARK: - Initialization
    init(store: PostStore) {
        self.store = store
        // Пробрасываем изменения из PostStore, чтобы список тегов обновлялся без ручного objectWillChange
        self.storeCancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: - Computed Properties
    var currentTags: [String] {
        tagCategory == 0 ? store.goodTags : store.badTags
    }
    
    var isNewTagEmpty: Bool {
        newTag.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var isEditingTagEmpty: Bool {
        editingTagText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Tag Management Methods
    
    /// Добавить новый тег
    func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if tagCategory == 0 {
            store.addGoodTag(trimmed)
        } else {
            store.addBadTag(trimmed)
        }
        
        newTag = ""
        
        // Обновляем провайдера тегов в фоне, чтобы не блокировать UI
        Task.detached(priority: .background) { [tagProvider] in
            await tagProvider?.refresh()
        }
    }
    
    /// Начать редактирование тега
    func startEditTag(_ idx: Int) {
        editingTagIndex = idx
        editingTagText = currentTags[idx]
    }
    
    /// Завершить редактирование тега
    func finishEditTag() {
        guard let idx = editingTagIndex else { return }
        let trimmed = editingTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let old = currentTags[idx]
        if tagCategory == 0 {
            store.updateGoodTag(old: old, new: trimmed)
        } else {
            store.updateBadTag(old: old, new: trimmed)
        }
        
        editingTagIndex = nil
        editingTagText = ""
        
        // Обновляем провайдера тегов в фоне, чтобы не блокировать UI
        Task.detached(priority: .background) { [tagProvider] in
            await tagProvider?.refresh()
        }
    }
    
    /// Удалить тег
    func deleteTag() {
        guard let tag = tagToDelete else { return }
        
        if tagCategory == 0 {
            store.removeGoodTag(tag)
        } else {
            store.removeBadTag(tag)
        }
        
        tagToDelete = nil
        
        // Обновляем провайдера тегов в фоне, чтобы не блокировать UI
        Task.detached(priority: .background) { [tagProvider] in
            await tagProvider?.refresh()
        }
    }
    
    /// Подготовить удаление тега
    func prepareDeleteTag(_ tag: String) {
        tagToDelete = tag
        showDeleteTagAlert = true
    }
    
    /// Отменить удаление тега
    func cancelDeleteTag() {
        tagToDelete = nil
        showDeleteTagAlert = false
    }
    
    /// Загрузить теги (legacy): теперь только refresh провайдера
    func loadTags() {
        Task.detached(priority: .background) { [tagProvider] in
            await tagProvider?.refresh()
        }
    }
} 