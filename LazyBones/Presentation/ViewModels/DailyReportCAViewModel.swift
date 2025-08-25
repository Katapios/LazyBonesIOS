import Foundation
import SwiftUI

@MainActor
final class DailyReportCAViewModel: ObservableObject {
    // Dependencies
    private let loadDraftUC: LoadRegularReportDraftUseCase
    private let saveDraftUC: SaveRegularReportDraftUseCase
    private let removeTodayUC: RemoveTodayRegularReportUseCase
    private let publishUC: PublishRegularReportUseCase
    private let saveLocalUC: SaveRegularReportAsLocalUseCase
    private let tagProvider: TagProviderProtocol?
    private let reportStatusManager: (any ReportStatusManagerProtocol)?

    // UI State
    @Published var selectedTab: Int = 0 // 0: good, 1: bad
    @Published var goodItems: [String] = []
    @Published var badItems: [String] = []
    @Published var tags: [String] = []
    @Published var voiceNotes: [VoiceNote] = []
    @Published var newGoodText: String = ""
    @Published var newBadText: String = ""
    @Published var publishStatus: String? = nil
    @Published var isPublishing: Bool = false
    @Published var showTagPicker: Bool = false
    @Published var pickerIndex: Int = 0

    // Derived
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    init(
        loadDraftUC: LoadRegularReportDraftUseCase = DependencyContainer.shared.resolve(LoadRegularReportDraftUseCase.self)!,
        saveDraftUC: SaveRegularReportDraftUseCase = DependencyContainer.shared.resolve(SaveRegularReportDraftUseCase.self)!,
        removeTodayUC: RemoveTodayRegularReportUseCase = DependencyContainer.shared.resolve(RemoveTodayRegularReportUseCase.self)!,
        publishUC: PublishRegularReportUseCase = DependencyContainer.shared.resolve(PublishRegularReportUseCase.self)!,
        saveLocalUC: SaveRegularReportAsLocalUseCase = DependencyContainer.shared.resolve(SaveRegularReportAsLocalUseCase.self)!,
        tagProvider: TagProviderProtocol? = DependencyContainer.shared.resolve(TagProviderProtocol.self),
        reportStatusManager: (any ReportStatusManagerProtocol)? = DependencyContainer.shared.resolve((any ReportStatusManagerProtocol).self)
    ) {
        self.loadDraftUC = loadDraftUC
        self.saveDraftUC = saveDraftUC
        self.removeTodayUC = removeTodayUC
        self.publishUC = publishUC
        self.saveLocalUC = saveLocalUC
        self.tagProvider = tagProvider
        self.reportStatusManager = reportStatusManager
    }

    // MARK: - Lifecycle
    func onAppear() {
        // Теги
        Task { [weak self] in
            guard let self else { return }
            await self.tagProvider?.refresh()
            if let allTags = self.tagProvider?.goodTags { // переиспользуем набор тегов; в легаси есть good/bad кольца
                await MainActor.run {
                    self.tags = allTags
                }
            }
        }
        // Драфт
        loadDraft()
    }

    // MARK: - Draft
    func loadDraft() {
        if let draft = loadDraftUC.execute(date: today) {
            self.goodItems = draft.good
            self.badItems = draft.bad
            self.voiceNotes = draft.voiceNotes
            self.tags = draft.tags.isEmpty ? self.tags : draft.tags
        }
    }

    func saveDraft() {
        let draft = RegularReportDraft(
            date: today,
            good: goodItems,
            bad: badItems,
            voiceNotes: voiceNotes,
            tags: tags,
            published: false
        )
        saveDraftUC.execute(draft)
    }

    // MARK: - Form actions
    func addGood() {
        let t = newGoodText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        goodItems.append(t)
        newGoodText = ""
        saveDraft()
    }

    func addBad() {
        let t = newBadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        badItems.append(t)
        newBadText = ""
        saveDraft()
    }

    func removeGood(at offsets: IndexSet) {
        goodItems.remove(atOffsets: offsets)
        saveDraft()
    }

    func removeBad(at offsets: IndexSet) {
        badItems.remove(atOffsets: offsets)
        saveDraft()
    }

    func attachVoiceNote(_ note: VoiceNote) {
        voiceNotes.append(note)
        saveDraft()
    }

    func removeVoiceNote(id: UUID) {
        voiceNotes.removeAll { $0.id == id }
        saveDraft()
    }

    // MARK: - Tags
    func selectTag(at index: Int) {
        guard let provider = tagProvider else { return }
        if index < provider.goodTags.count {
            let tg = provider.goodTags[index]
            if !tags.contains(tg) { tags.append(tg) }
            pickerIndex = index
            showTagPicker = true
            saveDraft()
        }
    }

    func addManualTag(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !tags.contains(t) { tags.append(t) }
        saveDraft()
    }

    func removeTag(_ t: String) {
        tags.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        saveDraft()
    }

    // MARK: - Report actions
    func removeTodayReport() {
        removeTodayUC.execute()
        publishStatus = "Черновик отчета за сегодня удален"
    }

    func saveAsLocalReport() {
        let draft = RegularReportDraft(
            date: today,
            good: goodItems,
            bad: badItems,
            voiceNotes: voiceNotes,
            tags: tags,
            published: false
        )
        saveLocalUC.execute(draft)
        publishStatus = nil
    }

    func publishToTelegram() {
        isPublishing = true
        let draft = RegularReportDraft(
            date: today,
            good: goodItems,
            bad: badItems,
            voiceNotes: voiceNotes,
            tags: tags,
            published: false
        )
        publishUC.execute(draft) { [weak self] ok in
            guard let self else { return }
            Task { @MainActor in
                self.isPublishing = false
                self.publishStatus = ok ? "Отчет отправлен" : "Ошибка отправки"
                if ok {
                    // После успешной отправки можно запросить обновление статуса
                    self.reportStatusManager?.updateStatus()
                }
            }
        }
    }
}
