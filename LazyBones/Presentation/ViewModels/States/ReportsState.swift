import Foundation

/// Состояние для общего экрана отчетов
struct ReportsState {
    // MARK: - Data
    var regularReports: [DomainPost] = []
    var customReports: [DomainPost] = []
    var externalReports: [DomainPost] = []
    var goodTags: [String] = []
    var badTags: [String] = []
    
    // MARK: - UI State
    var isSelectionMode: Bool = false
    var selectedLocalReportIDs: Set<UUID> = []
    var showEvaluationSheet: Bool = false
    var evaluatingPost: DomainPost? = nil
    var allowCustomReportReevaluation: Bool = false
    var isLoading: Bool = false
    var error: Error? = nil
    
    // MARK: - Computed Properties
    var hasRegularPosts: Bool {
        !regularReports.isEmpty
    }
    
    var hasCustomPosts: Bool {
        !customReports.isEmpty
    }
    
    var hasExternalPosts: Bool {
        !externalReports.isEmpty
    }
    
    var selectedRegularPosts: [DomainPost] {
        regularReports.filter { selectedLocalReportIDs.contains($0.id) }
    }
    
    var selectedCustomPosts: [DomainPost] {
        customReports.filter { selectedLocalReportIDs.contains($0.id) }
    }
    
    var canSelectAllRegular: Bool {
        selectedRegularPosts.count == 0 || selectedRegularPosts.count == regularReports.count
    }
    
    var canSelectAllCustom: Bool {
        selectedCustomPosts.count == 0 || selectedCustomPosts.count == customReports.count
    }
    
    var selectAllRegularText: String {
        selectedRegularPosts.count == regularReports.count ? "Снять все" : "Выбрать все"
    }
    
    var selectAllCustomText: String {
        selectedCustomPosts.count == customReports.count ? "Снять все" : "Выбрать все"
    }
    
    var selectedReportsCount: Int {
        selectedLocalReportIDs.count
    }
    
    var hasSelectedReports: Bool {
        !selectedLocalReportIDs.isEmpty
    }
    
    var canDeleteReports: Bool {
        isSelectionMode && hasSelectedReports
    }
}

/// События для общего экрана отчетов
enum ReportsEvent {
    // MARK: - Data Loading
    case loadReports
    case refreshReports
    case loadTags
    
    // MARK: - Selection
    case toggleSelectionMode
    case toggleSelection(UUID)
    case selectAllRegularReports
    case selectAllCustomReports
    case clearSelection
    
    // MARK: - Actions
    case deleteSelectedReports
    case startEvaluation(DomainPost)
    case completeEvaluation([Bool])
    case updateReevaluationSettings(Bool)
    case sendCustomReport(DomainPost)
    case sendRegularReport(DomainPost)
    
    // MARK: - UI
    case clearError
} 