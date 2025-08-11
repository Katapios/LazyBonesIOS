import Foundation
import SwiftUI

@MainActor
final class PlanningViewModelNew: ObservableObject {
    // MARK: - Published
    @Published var planItems: [String] = []
    @Published var newTag: String = ""
    @Published var pickerIndex: Int = 0
    @Published var showTagPicker: Bool = false
    @Published var goodTags: [String] = []
    @Published var statusMessage: String? = nil
    @Published var isLoading: Bool = false
    
    // MARK: - DI
    private let tagRepository: any TagRepositoryProtocol
    private let getReportsUseCase: GetReportsUseCase
    private let deleteReportUseCase: DeleteReportUseCase
    private let updateReportUseCase: UpdateReportUseCase
    private let postTelegramService: any PostTelegramServiceProtocol
    
    // MARK: - Init
    init(
        tagRepository: any TagRepositoryProtocol,
        getReportsUseCase: GetReportsUseCase,
        deleteReportUseCase: DeleteReportUseCase,
        updateReportUseCase: UpdateReportUseCase,
        postTelegramService: any PostTelegramServiceProtocol
    ) {
        self.tagRepository = tagRepository
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        self.updateReportUseCase = updateReportUseCase
        self.postTelegramService = postTelegramService
        
        // Подписка на изменения тегов
        NotificationCenter.default.addObserver(
            forName: .tagsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadTags()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    func load() async {
        await loadTags()
        loadPlanFromStorage()
    }
    
    func loadTags() async {
        do {
            self.goodTags = try await tagRepository.loadGoodTags()
            // Безопасно корректируем индекс колеса тегов
            if goodTags.isEmpty {
                pickerIndex = 0
            } else if !goodTags.indices.contains(pickerIndex) {
                pickerIndex = max(0, goodTags.count - 1)
            }
        } catch {
            Logger.error("Failed to load good tags: \(error)", log: Logger.ui)
        }
    }
    
    func addGoodTag(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await tagRepository.addGoodTag(trimmed)
            self.newTag = ""
            // success path обновится через .tagsDidChange
        } catch {
            Logger.error("Failed to add good tag: \(error)", log: Logger.ui)
        }
    }
    
    func addPlanItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        planItems.append(trimmed)
        savePlanToStorage()
    }
    
    func updatePlanItem(at index: Int, with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, planItems.indices.contains(index) else { return }
        planItems[index] = trimmed
        savePlanToStorage()
    }
    
    func removePlanItem(at index: Int) {
        guard planItems.indices.contains(index) else { return }
        planItems.remove(at: index)
        savePlanToStorage()
    }
    
    func toggleTagPicker() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showTagPicker.toggle()
        }
    }
    
    func addSelectedTag() {
        guard !goodTags.isEmpty, goodTags.indices.contains(pickerIndex) else { return }
        let tag = goodTags[pickerIndex]
        guard !planItems.contains(tag) else { return }
        planItems.append(tag)
        savePlanToStorage()
    }
    
    // Сохранить план в кастомный отчёт (без отправки)
    func savePlanAsCustomReport(using storeFallback: PostStore?) {
        // Для обратной совместимости оставляем лёгкий fallback на PostStore
        let today = Calendar.current.startOfDay(for: Date())
        if let store = storeFallback, let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: false,
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
        } else if let store = storeFallback {
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: false,
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
        savePlanToStorage()
    }
    
    // Отправка через ReportsViewModelNew
    func sendCustomReport() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Получаем кастомный отчёт за сегодня
            let input = GetReportsInput(date: Date(), type: .custom, includeExternal: false)
            let customs = try await getReportsUseCase.execute(input: input)
            let today = Calendar.current.startOfDay(for: Date())
            guard let post = customs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
                self.statusMessage = "Сначала сохраните план как отчет!"
                return
            }
            
            let vm = ReportsViewModelNew(
                getReportsUseCase: getReportsUseCase,
                deleteReportUseCase: deleteReportUseCase,
                updateReportUseCase: updateReportUseCase,
                tagRepository: tagRepository,
                postTelegramService: postTelegramService
            )
            await vm.handle(.sendCustomReport(post))
            if vm.state.error == nil {
                self.statusMessage = "План успешно опубликован!"
            } else {
                self.statusMessage = vm.state.error?.localizedDescription ?? "Ошибка отправки"
            }
        } catch {
            self.statusMessage = "Ошибка загрузки отчёта"
        }
    }
    
    // MARK: - Storage
    private func storageKey() -> String {
        return "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
    }
    
    private func savePlanToStorage() {
        let key = storageKey()
        if let data = try? JSONEncoder().encode(planItems) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func loadPlanFromStorage() {
        let key = storageKey()
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            planItems = decoded
        } else {
            planItems = []
        }
    }
}
