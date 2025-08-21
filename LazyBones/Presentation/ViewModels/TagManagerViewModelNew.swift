import Foundation
import Combine

@MainActor
final class TagManagerViewModelNew: ObservableObject {
    enum Segment: Int, CaseIterable {
        case good
        case bad
        
        var title: String {
            switch self {
            case .good: return "Хорошие"
            case .bad: return "Плохие"
            }
        }
    }
    
    // MARK: - Dependencies
    private let tagRepository: any TagRepositoryProtocol
    
    // MARK: - State
    @Published var goodTags: [String] = []
    @Published var badTags: [String] = []
    @Published var selectedSegment: Segment = .good
    @Published var newTagText: String = ""
    @Published var alertMessage: String?
    
    // Editing
    @Published var tagToDelete: (segment: Segment, value: String)?
    @Published var tagBeingEdited: (segment: Segment, oldValue: String, newValue: String)?
    
    // MARK: - Init
    init(tagRepository: any TagRepositoryProtocol) {
        self.tagRepository = tagRepository
    }
    
    // MARK: - Public API
    func load() async {
        do {
            async let good = tagRepository.loadGoodTags()
            async let bad = tagRepository.loadBadTags()
            let (g, b) = try await (good, bad)
            self.goodTags = g
            self.badTags = b
        } catch {
            self.alertMessage = "Не удалось загрузить теги: \(error.localizedDescription)"
        }
    }
    
    func addNewTag() async {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch selectedSegment {
        case .good:
            guard !goodTags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
                alertMessage = "Такой тег уже существует"
                return
            }
            do {
                try await tagRepository.addGoodTag(trimmed)
                goodTags.append(trimmed)
                newTagText = ""
                // sync provider
                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                await provider?.refresh()
            } catch {
                alertMessage = "Ошибка добавления тега: \(error.localizedDescription)"
            }
        case .bad:
            guard !badTags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
                alertMessage = "Такой тег уже существует"
                return
            }
            do {
                try await tagRepository.addBadTag(trimmed)
                badTags.append(trimmed)
                newTagText = ""
                // sync provider
                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                await provider?.refresh()
            } catch {
                alertMessage = "Ошибка добавления тега: \(error.localizedDescription)"
            }
        }
    }
    
    func requestDelete(segment: Segment, value: String) {
        tagToDelete = (segment, value)
    }
    
    func confirmDelete() async {
        guard let item = tagToDelete else { return }
        tagToDelete = nil
        do {
            switch item.segment {
            case .good:
                try await tagRepository.removeGoodTag(item.value)
                goodTags.removeAll { $0 == item.value }
            case .bad:
                try await tagRepository.removeBadTag(item.value)
                badTags.removeAll { $0 == item.value }
            }
            // sync provider
            let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
            await provider?.refresh()
        } catch {
            alertMessage = "Ошибка удаления: \(error.localizedDescription)"
        }
    }
    
    func startEditing(segment: Segment, oldValue: String) {
        tagBeingEdited = (segment, oldValue, oldValue)
    }
    
    func applyEdit() async {
        guard let edit = tagBeingEdited else { return }
        let newTrimmed = edit.newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTrimmed.isEmpty else { return }
        
        do {
            switch edit.segment {
            case .good:
                try await tagRepository.updateGoodTag(old: edit.oldValue, new: newTrimmed)
                if let idx = goodTags.firstIndex(of: edit.oldValue) { goodTags[idx] = newTrimmed }
            case .bad:
                try await tagRepository.updateBadTag(old: edit.oldValue, new: newTrimmed)
                if let idx = badTags.firstIndex(of: edit.oldValue) { badTags[idx] = newTrimmed }
            }
            tagBeingEdited = nil
            // sync provider
            let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
            await provider?.refresh()
        } catch {
            alertMessage = "Ошибка изменения тега: \(error.localizedDescription)"
        }
    }
}
