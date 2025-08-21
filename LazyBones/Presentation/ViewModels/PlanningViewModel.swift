import Foundation
import SwiftUI

@MainActor
class PlanningViewModel: ObservableObject {
    // Dependencies
    @Published var store: PostStore
    private let planningRepository: PlanningRepositoryProtocol
    private let tagProvider: TagProviderProtocol?
    
    // UI State
    @Published var planItems: [String] = []
    @Published var newPlanItem: String = ""
    @Published var editingPlanIndex: Int? = nil
    @Published var editingPlanText: String = ""
    @Published var showSaveAlert = false
    @Published var showDeletePlanAlert = false
    @Published var planToDeleteIndex: Int? = nil
    @Published var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var publishStatus: String? = nil
    @Published var pickerIndex: Int = 0
    @Published var showTagPicker: Bool = false
    
    init(store: PostStore, planningRepository: PlanningRepositoryProtocol = DependencyContainer.shared.resolve(PlanningRepositoryProtocol.self)!) {
        self.store = store
        self.planningRepository = planningRepository
        self.tagProvider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
    }
    
    // Computed
    var planTags: [TagItem] {
        let source = tagProvider?.goodTags ?? store.goodTags
        return source.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    // Lifecycle helpers
    func onAppear() {
        store.loadTags()
        Task { await tagProvider?.refresh() }
        store.loadTelegramSettings()
        loadPlan()
        lastPlanDate = Calendar.current.startOfDay(for: Date())
    }
    
    func handleDayChangeIfNeeded() {
        let newDay = Calendar.current.startOfDay(for: Date())
        if newDay != lastPlanDate {
            planItems = []
            savePlan()
            lastPlanDate = newDay
        }
    }
    
    // Actions
    func addPlanItem() {
        let trimmed = newPlanItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems.append(trimmed)
        newPlanItem = ""
        savePlan()
    }
    
    func startEditPlanItem(_ idx: Int) {
        editingPlanIndex = idx
        editingPlanText = planItems[idx]
    }
    
    func finishEditPlanItem() {
        guard let idx = editingPlanIndex else { return }
        let trimmed = editingPlanText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems[idx] = trimmed
        editingPlanIndex = nil
        editingPlanText = ""
        savePlan()
    }
    
    func deletePlanItem() {
        guard let idx = planToDeleteIndex else { return }
        planItems.remove(at: idx)
        planToDeleteIndex = nil
        savePlan()
    }
    
    func savePlan() {
        planningRepository.savePlan(planItems, for: Date())
    }
    
    func loadPlan() {
        let items = planningRepository.loadPlan(for: Date())
        planItems = items
    }
    
    func savePlanAsReport() {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .custom,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.posts[idx] = updated
            store.save()
        } else {
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: true,
                voiceNotes: [],
                type: .custom,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.add(post: post)
        }
        savePlan()
    }
    
    func publishCustomReportToTelegram() {
        store.load()
        let today = Calendar.current.startOfDay(for: Date())
        guard let customIndex = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
            publishStatus = "Сначала сохраните план как отчет!"
            return
        }
        let custom = store.posts[customIndex]
        if custom.isEvaluated != true {
            publishStatus = "Сначала оцените план!"
            return
        }
        store.loadTelegramSettings()
        let deviceName = store.getDeviceName()
        let message = store.telegramIntegrationService.formatCustomReportForTelegram(custom, deviceName: deviceName)
        store.sendToTelegram(text: message) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.publishStatus = "План успешно опубликован!"
                } else {
                    self?.publishStatus = "Ошибка отправки: неверный токен или chat_id"
                }
            }
        }
    }
}
