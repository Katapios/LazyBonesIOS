import Foundation
import SwiftUI

@MainActor
final class TagManagerViewModelNew: ObservableObject {
    // MARK: - Dependencies
    private let tagRepository: any TagRepositoryProtocol
    
    // MARK: - UI State
    @Published var tagCategory: Int = 0 // 0 — good, 1 — bad
    @Published var newTag: String = ""
    @Published var editingTagIndex: Int? = nil
    @Published var editingTagText: String = ""
    @Published var showDeleteTagAlert = false
    @Published var tagToDelete: String? = nil
    @Published var goodTags: [String] = []
    @Published var badTags: [String] = []
    
    // MARK: - Init
    init(tagRepository: any TagRepositoryProtocol) {
        self.tagRepository = tagRepository
        // Подписка на изменения тегов из PostStore/репозитория
        NotificationCenter.default.addObserver(self, selector: #selector(handleTagsDidChange), name: .tagsDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Derived
    var currentTags: [String] {
        tagCategory == 0 ? goodTags : badTags
    }
    
    var isNewTagEmpty: Bool { newTag.trimmingCharacters(in: .whitespaces).isEmpty }
    var isEditingTagEmpty: Bool { editingTagText.trimmingCharacters(in: .whitespaces).isEmpty }
    
    // MARK: - Intents
    func loadTags() async {
        do {
            async let good = tagRepository.loadGoodTags()
            async let bad = tagRepository.loadBadTags()
            let (g, b) = try await (good, bad)
            goodTags = g
            badTags = b
        } catch {
            Logger.error("Failed to load tags: \(error)", log: Logger.ui)
        }
    }
    
    func addTag() async {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            if tagCategory == 0 {
                try await tagRepository.addGoodTag(trimmed)
            } else {
                try await tagRepository.addBadTag(trimmed)
            }
            newTag = ""
            await loadTags()
        } catch {
            Logger.error("Failed to add tag: \(error)", log: Logger.ui)
        }
    }
    
    func startEditTag(_ idx: Int) {
        editingTagIndex = idx
        editingTagText = currentTags[idx]
    }
    
    func finishEditTag() async {
        guard let idx = editingTagIndex else { return }
        let trimmed = editingTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let old = currentTags[idx]
            if tagCategory == 0 {
                try await tagRepository.updateGoodTag(old: old, new: trimmed)
            } else {
                try await tagRepository.updateBadTag(old: old, new: trimmed)
            }
            editingTagIndex = nil
            editingTagText = ""
            await loadTags()
        } catch {
            Logger.error("Failed to edit tag: \(error)", log: Logger.ui)
        }
    }
    
    func prepareDeleteTag(_ tag: String) {
        tagToDelete = tag
        showDeleteTagAlert = true
    }
    
    func cancelDeleteTag() {
        tagToDelete = nil
        showDeleteTagAlert = false
    }
    
    func deleteTag() async {
        guard let tag = tagToDelete else { return }
        do {
            if tagCategory == 0 {
                try await tagRepository.removeGoodTag(tag)
            } else {
                try await tagRepository.removeBadTag(tag)
            }
            tagToDelete = nil
            await loadTags()
        } catch {
            Logger.error("Failed to delete tag: \(error)", log: Logger.ui)
        }
    }
    
    // MARK: - Notifications
    @objc private func handleTagsDidChange() {
        Task { [weak self] in
            await self?.loadTags()
        }
    }
}
