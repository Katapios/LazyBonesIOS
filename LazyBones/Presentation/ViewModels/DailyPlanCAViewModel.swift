import Foundation
import SwiftUI

@MainActor
final class DailyPlanCAViewModel: ObservableObject {
    // Dependencies (resolved via DI)
    private let loadPlanUC: LoadPlanDraftUseCase
    private let savePlanUC: SavePlanDraftUseCase
    private let createCustomFromDraftUC: CreateCustomReportFromDraftUseCase
    private let publishCustomUC: PublishCustomReportUseCase
    private let tagProvider: TagProviderProtocol?
    private let tagRepository: TagRepositoryProtocol?

    // UI State
    @Published var planItems: [String] = []
    @Published var newPlanItem: String = ""
    @Published var editingPlanIndex: Int? = nil
    @Published var editingPlanText: String = ""
    @Published var showSaveAlert = false
    @Published var showDeletePlanAlert = false
    @Published var planToDeleteIndex: Int? = nil
    @Published var publishStatus: String? = nil
    @Published var pickerIndex: Int = 0
    @Published var showTagPicker: Bool = false

    // Tags data (stubbed for now, will be provided via TagProvider use-cases)
    @Published var planTags: [TagItem] = []

    init(
        loadPlanUC: LoadPlanDraftUseCase = DependencyContainer.shared.resolve(LoadPlanDraftUseCase.self)!,
        savePlanUC: SavePlanDraftUseCase = DependencyContainer.shared.resolve(SavePlanDraftUseCase.self)!,
        createCustomFromDraftUC: CreateCustomReportFromDraftUseCase = DependencyContainer.shared.resolve(CreateCustomReportFromDraftUseCase.self)!,
        publishCustomUC: PublishCustomReportUseCase = DependencyContainer.shared.resolve(PublishCustomReportUseCase.self)!,
        tagProvider: TagProviderProtocol? = DependencyContainer.shared.resolve(TagProviderProtocol.self),
        tagRepository: TagRepositoryProtocol? = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
    ) {
        self.loadPlanUC = loadPlanUC
        self.savePlanUC = savePlanUC
        self.createCustomFromDraftUC = createCustomFromDraftUC
        self.publishCustomUC = publishCustomUC
        self.tagProvider = tagProvider
        self.tagRepository = tagRepository
    }

    // Lifecycle
    func onAppear() {
        Task { [weak self] in
            guard let self else { return }
            // Tags
            await tagProvider?.refresh()
            if let goods = tagProvider?.goodTags {
                self.planTags = goods.map { TagItem(text: $0, icon: "tag", color: .green) }
            }
            // Plan draft
            let today = Date()
            if let items = try? await loadPlanUC.execute(input: LoadPlanDraftInput(date: today)) {
                self.planItems = items
            }
        }
    }

    func handleDayChangeIfNeeded() {
        // TODO: implement day change handling similar to legacy if needed
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
        Task { [savePlanUC, planItems] in
            let input = SavePlanDraftInput(date: Date(), items: planItems)
            _ = try? await savePlanUC.execute(input: input)
        }
    }

    func savePlanAsReport() {
        Task { [weak self] in
            guard let self else { return }
            let input = CreateCustomReportFromDraftInput(date: Date(), items: self.planItems)
            do {
                _ = try await self.createCustomFromDraftUC.execute(input: input)
                await MainActor.run {
                    self.publishStatus = "План сохранен как кастомный отчет"
                }
            } catch {
                await MainActor.run {
                    self.publishStatus = "Ошибка сохранения отчета"
                }
            }
        }
    }

    func publishCustomReportToTelegram() {
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await publishCustomUC.execute(input: PublishCustomReportInput(date: Date()))
                await MainActor.run { self.publishStatus = "План успешно опубликован!" }
            } catch let error as PublishCustomReportError {
                let message: String
                switch error {
                case .notEvaluated:
                    message = "Сначала оцените план!"
                case .reportNotFound:
                    message = "Сначала сохраните план как отчет!"
                case .formatError:
                    message = "Ошибка форматирования сообщения"
                case .sendFailed:
                    message = "Ошибка отправки: неверный токен или chat_id"
                }
                await MainActor.run { self.publishStatus = message }
            } catch {
                await MainActor.run { self.publishStatus = "Неизвестная ошибка отправки" }
            }
        }
    }

    // MARK: - Tags
    func saveNewTag(_ rawText: String) {
        let t = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            if let tagRepository {
                try? await tagRepository.addGoodTag(t)
            }
            await tagProvider?.refresh()
            if let goods = tagProvider?.goodTags {
                let items = goods.map { TagItem(text: $0, icon: "tag", color: .green) }
                await MainActor.run {
                    self.planTags = items
                    if let idx = goods.firstIndex(of: t) {
                        self.pickerIndex = idx
                        self.showTagPicker = true
                    }
                }
            }
        }
    }
}
