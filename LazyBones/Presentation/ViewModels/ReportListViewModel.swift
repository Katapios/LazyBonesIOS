import Foundation

/// ViewModel для списка отчетов
@MainActor
class ReportListViewModel: BaseViewModel<ReportListState, ReportListEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    private let deleteReportUseCase: any DeleteReportUseCaseProtocol
    
    init(
        getReportsUseCase: any GetReportsUseCaseProtocol,
        deleteReportUseCase: any DeleteReportUseCaseProtocol
    ) {
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        super.init(initialState: ReportListState())
    }
    
    override func handle(_ event: ReportListEvent) async {
        switch event {
        case .loadReports:
            await load()
        case .refreshReports:
            await load()
        case .selectDate(let date):
            state.selectedDate = date
        case .filterByType(let type):
            state.filterType = type
        case .toggleExternalReports:
            state.showExternalReports.toggle()
        case .deleteReport(let report):
            await deleteReport(report)
        case .editReport(_):
            // TODO: Navigate to edit screen
            break
        }
    }
    
    func load() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let input = GetReportsInput(
                date: state.selectedDate,
                type: state.filterType,
                includeExternal: state.showExternalReports
            )
            let reports = try await getReportsUseCase.execute(input: input)
            state.reports = reports
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func deleteReport(_ report: DomainPost) async {
        do {
            try await deleteReportUseCase.execute(input: DeleteReportInput(report: report))
            await load() // Reload reports after deletion
        } catch {
            state.error = error
        }
    }
} 