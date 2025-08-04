import Foundation

/// ViewModel для кастомных отчетов
@MainActor
class CustomReportsViewModel: BaseViewModel<CustomReportsState, CustomReportsEvent>, LoadableViewModel {

    @Published var isLoading: Bool = false
    @Published var error: Error? = nil

    private let createReportUseCase: CreateReportUseCase
    private let getReportsUseCase: GetReportsUseCase
    private let deleteReportUseCase: DeleteReportUseCase
    private let updateReportUseCase: UpdateReportUseCase

    init(
        createReportUseCase: CreateReportUseCase,
        getReportsUseCase: GetReportsUseCase,
        deleteReportUseCase: DeleteReportUseCase,
        updateReportUseCase: UpdateReportUseCase
    ) {
        self.createReportUseCase = createReportUseCase
        self.getReportsUseCase = getReportsUseCase
        self.deleteReportUseCase = deleteReportUseCase
        self.updateReportUseCase = updateReportUseCase
        super.init(initialState: CustomReportsState())
    }

    // MARK: - LoadableViewModel
    
    func load() async {
        await loadReports()
    }

    override func handle(_ event: CustomReportsEvent) async {
        switch event {
        case .loadReports:
            await loadReports()
        case .refreshReports:
            await loadReports()
        case .createReport(let goodItems, let badItems):
            await createReport(goodItems: goodItems, badItems: badItems)
        case .evaluateReport(let report, let results):
            await evaluateReport(report, results: results)
        case .reEvaluateReport(let report, let results):
            await reEvaluateReport(report, results: results)
        case .deleteReport(let report):
            await deleteReport(report)
        case .editReport(let report):
            await editReport(report)
        case .selectDate(let date):
            state.selectedDate = date
            await loadReports()
        case .toggleSelectionMode:
            state.isSelectionMode.toggle()
            if !state.isSelectionMode {
                state.selectedReportIDs.removeAll()
            }
        case .selectReport(let id):
            if state.selectedReportIDs.contains(id) {
                state.selectedReportIDs.remove(id)
            } else {
                state.selectedReportIDs.insert(id)
            }
        case .selectAllReports:
            state.selectedReportIDs = Set(state.reports.map { $0.id })
        case .deselectAllReports:
            state.selectedReportIDs.removeAll()
        case .deleteSelectedReports:
            await deleteSelectedReports()
        case .clearError:
            state.error = nil
        }
    }

    // MARK: - Private Methods

    private func loadReports() async {
        state.isLoading = true
        state.error = nil

        do {
            let input = GetReportsInput(date: state.selectedDate, type: .custom)
            let reports = try await getReportsUseCase.execute(input: input)
            state.reports = reports
            updateButtonStates()
        } catch {
            state.error = error
        }
        state.isLoading = false
    }

    private func createReport(goodItems: [String], badItems: [String]) async {
        state.isLoading = true
        state.error = nil

        do {
            let input = CreateReportInput(
                goodItems: goodItems,
                badItems: badItems,
                type: .custom
            )
            let newReport = try await createReportUseCase.execute(input: input)
            state.reports.append(newReport)
            updateButtonStates()
        } catch {
            state.error = error
        }
        state.isLoading = false
    }

    private func evaluateReport(_ report: DomainPost, results: [Bool]) async {
        state.isLoading = true
        state.error = nil

        do {
            var updatedReport = report
            updatedReport.evaluationResults = results
            updatedReport.isEvaluated = true

            let input = UpdateReportInput(report: updatedReport)
            _ = try await updateReportUseCase.execute(input: input)

            if let index = state.reports.firstIndex(where: { $0.id == report.id }) {
                state.reports[index] = updatedReport
            }
            updateButtonStates()
        } catch {
            state.error = error
        }
        state.isLoading = false
    }

    private func reEvaluateReport(_ report: DomainPost, results: [Bool]) async {
        // Переоценка работает так же, как обычная оценка
        await evaluateReport(report, results: results)
    }

    private func deleteReport(_ report: DomainPost) async {
        state.isLoading = true
        state.error = nil

        do {
            let input = DeleteReportInput(report: report)
            try await deleteReportUseCase.execute(input: input)

            state.reports.removeAll { $0.id == report.id }
            updateButtonStates()
        } catch {
            state.error = error
        }
        state.isLoading = false
    }

    private func editReport(_ report: DomainPost) async {
        // TODO: Навигация к экрану редактирования
        // Пока просто логируем
        print("Edit custom report: \(report.id)")
    }

    private func deleteSelectedReports() async {
        state.isLoading = true
        state.error = nil

        do {
            let reportsToDelete = state.reports.filter { state.selectedReportIDs.contains($0.id) }

            for report in reportsToDelete {
                let input = DeleteReportInput(report: report)
                try await deleteReportUseCase.execute(input: input)
            }

            state.reports.removeAll { state.selectedReportIDs.contains($0.id) }
            state.selectedReportIDs.removeAll()
            state.isSelectionMode = false
            updateButtonStates()
        } catch {
            state.error = error
        }
        state.isLoading = false
    }

    private func updateButtonStates() {
        // Можно создать отчет, если нет активного отчета на сегодня
        let today = Calendar.current.startOfDay(for: Date())
        let hasActiveReportToday = state.reports.contains { report in
            Calendar.current.isDate(report.date, inSameDayAs: today) && report.isEvaluated != true
        }
        state.canCreateReport = !hasActiveReportToday

        // Можно оценить отчет, если есть неоцененные отчеты за сегодня
        let hasUnevaluatedReportsToday = state.reports.contains { report in
            Calendar.current.isDate(report.date, inSameDayAs: today) && report.isEvaluated != true
        }
        state.canEvaluateReport = hasUnevaluatedReportsToday
    }
} 