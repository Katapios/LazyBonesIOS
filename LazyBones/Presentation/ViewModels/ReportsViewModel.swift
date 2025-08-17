import Foundation
import SwiftUI

/// ViewModel-адаптер для ReportsView, который оборачивает PostStore
/// Это безопасный переходный этап миграции
@available(*, deprecated, message: "Legacy PostStore-based VM. Not used in runtime; kept for reference/tests during migration.")
@MainActor
class ReportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var store: PostStore
    @Published var isSelectionMode: Bool = false
    @Published var selectedLocalReportIDs: Set<UUID> = []
    @Published var showEvaluationSheet: Bool = false
    @Published var evaluatingPost: Post? = nil
    @Published var allowCustomReportReevaluation: Bool = false
    
    // MARK: - Computed Properties
    var posts: [Post] { store.posts }
    var externalPosts: [Post] { store.externalPosts }
    var goodTags: [String] { store.goodTags }
    var badTags: [String] { store.badTags }
    
    // MARK: - Filtered Posts
    var regularPosts: [Post] {
        posts.filter { $0.type == .regular }
    }
    
    var customPosts: [Post] {
        posts.filter { $0.type == .custom }
    }
    
    var hasRegularPosts: Bool {
        !regularPosts.isEmpty
    }
    
    var hasCustomPosts: Bool {
        !customPosts.isEmpty
    }
    
    // MARK: - Selection State
    var selectedRegularPosts: [Post] {
        regularPosts.filter { selectedLocalReportIDs.contains($0.id) }
    }
    
    var selectedCustomPosts: [Post] {
        customPosts.filter { selectedLocalReportIDs.contains($0.id) }
    }
    
    var canSelectAllRegular: Bool {
        selectedRegularPosts.count == 0 || selectedRegularPosts.count == regularPosts.count
    }
    
    var canSelectAllCustom: Bool {
        selectedCustomPosts.count == 0 || selectedCustomPosts.count == customPosts.count
    }
    
    var selectAllRegularText: String {
        selectedRegularPosts.count == regularPosts.count ? "Снять все" : "Выбрать все"
    }
    
    var selectAllCustomText: String {
        selectedCustomPosts.count == customPosts.count ? "Снять все" : "Выбрать все"
    }
    
    // MARK: - Initialization
    init(store: PostStore) {
        self.store = store
        
        // Загружаем настройки
        self.allowCustomReportReevaluation = UserDefaults.standard.bool(forKey: "allowCustomReportReevaluation")
    }
    
    // MARK: - Public Methods
    
    /// Загрузить отчеты
    func loadReports() {
        store.load()
        objectWillChange.send()
    }
    
    /// Принудительно обновить UI
    func refreshUI() {
        objectWillChange.send()
    }
    
    /// Обновить отчеты
    func refreshReports() {
        store.load()
    }
    
    /// Переключить режим выбора
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedLocalReportIDs.removeAll()
        }
    }
    
    /// Переключить выбор отчета
    func toggleSelection(for id: UUID) {
        if selectedLocalReportIDs.contains(id) {
            selectedLocalReportIDs.remove(id)
        } else {
            selectedLocalReportIDs.insert(id)
        }
    }
    
    /// Выбрать все обычные отчеты
    func selectAllRegularReports() {
        if selectedRegularPosts.count == regularPosts.count {
            selectedLocalReportIDs.removeAll()
        } else {
            selectedLocalReportIDs = Set(regularPosts.map { $0.id })
        }
    }
    
    /// Выбрать все кастомные отчеты
    func selectAllCustomReports() {
        if selectedCustomPosts.count == customPosts.count {
            selectedLocalReportIDs.removeAll()
        } else {
            selectedLocalReportIDs = Set(customPosts.map { $0.id })
        }
    }
    
    /// Удалить выбранные отчеты
    func deleteSelectedReports() {
        store.posts.removeAll { selectedLocalReportIDs.contains($0.id) }
        selectedLocalReportIDs.removeAll()
        isSelectionMode = false
        store.save()
    }
    
    /// Начать оценку отчета
    func startEvaluation(for post: Post) {
        evaluatingPost = post
        showEvaluationSheet = true
    }
    
    /// Завершить оценку отчета
    func completeEvaluation(results: [Bool]) {
        guard let post = evaluatingPost else { return }
        
        if let idx = store.posts.firstIndex(where: { $0.id == post.id }) {
            var updated = store.posts[idx]
            updated.evaluationResults = results
            updated.isEvaluated = true
            store.posts[idx] = updated
            evaluatingPost = updated
            store.save()
        }
        
        showEvaluationSheet = false
        evaluatingPost = nil
    }
    
    /// Обновить настройки переоценки
    func updateReevaluationSettings(_ enabled: Bool) {
        allowCustomReportReevaluation = enabled
        UserDefaults.standard.set(enabled, forKey: "allowCustomReportReevaluation")
    }
    
    /// Проверить, можно ли оценить отчет
    func canEvaluateReport(_ post: Post) -> Bool {
        Calendar.current.isDateInToday(post.date) && 
        !isSelectionMode && 
        (post.isEvaluated != true || allowCustomReportReevaluation) && 
        !post.goodItems.isEmpty
    }
    
    /// Проверить, оценен ли отчет
    func isReportEvaluated(_ post: Post) -> Bool {
        post.isEvaluated == true && !allowCustomReportReevaluation
    }
    
    /// Получить количество выбранных отчетов
    var selectedReportsCount: Int {
        selectedLocalReportIDs.count
    }
    
    /// Проверить, есть ли выбранные отчеты
    var hasSelectedReports: Bool {
        !selectedLocalReportIDs.isEmpty
    }
    
    /// Проверить, есть ли отчеты для удаления
    var canDeleteReports: Bool {
        isSelectionMode && hasSelectedReports
    }
} 