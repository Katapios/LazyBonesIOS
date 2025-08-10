import Foundation

/// ViewModel для обычных отчетов
@MainActor
class RegularReportsViewModel: BaseViewModel<RegularReportsState, RegularReportsEvent>, LoadableViewModel {
    
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
                private let createReportUseCase: CreateReportUseCase
            private let getReportsUseCase: GetReportsUseCase
            private let deleteReportUseCase: DeleteReportUseCase
            private let updateStatusUseCase: UpdateStatusUseCase
            private let updateReportUseCase: UpdateReportUseCase
    
                init(
                createReportUseCase: CreateReportUseCase,
                getReportsUseCase: GetReportsUseCase,
                deleteReportUseCase: DeleteReportUseCase,
                updateStatusUseCase: UpdateStatusUseCase,
                updateReportUseCase: UpdateReportUseCase
            ) {
                self.createReportUseCase = createReportUseCase
                self.getReportsUseCase = getReportsUseCase
                self.deleteReportUseCase = deleteReportUseCase
                self.updateStatusUseCase = updateStatusUseCase
                self.updateReportUseCase = updateReportUseCase
                super.init(initialState: RegularReportsState())
            }
    
    override func handle(_ event: RegularReportsEvent) async {
        switch event {
        case .loadReports:
            await loadReports()
        case .refreshReports:
            await loadReports()
        case .createReport(let goodItems, let badItems):
            await createReport(goodItems: goodItems, badItems: badItems)
        case .sendReport(let report):
            await sendReport(report)
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
    
    func load() async {
        await loadReports()
    }
    
    // MARK: - Private Methods
    
    private func loadReports() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let input = GetReportsInput(
                date: state.selectedDate,
                type: .regular,
                includeExternal: false
            )
            let reports = try await getReportsUseCase.execute(input: input)
            state.reports = reports
            
            // Обновляем состояние кнопок
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
                type: .regular
            )
            let newReport = try await createReportUseCase.execute(input: input)
            
            // Добавляем новый отчет в список
            state.reports.append(newReport)
            
            // Обновляем состояние кнопок
            updateButtonStates()
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func sendReport(_ report: DomainPost) async {
        state.isLoading = true
        state.error = nil
        
        do {
            // Обновляем статус отчета на "отправлен"
            var updatedReport = report
            updatedReport.published = true
            
            // Сохраняем изменения через Use Case
            let input = UpdateReportInput(report: updatedReport)
            _ = try await updateReportUseCase.execute(input: input)
            
            // Обновляем отчет в списке
            if let index = state.reports.firstIndex(where: { $0.id == report.id }) {
                state.reports[index] = updatedReport
            }
            
            // Обновляем состояние кнопок
            updateButtonStates()

            // Сообщаем приложению, что статус отчёта изменился (для MainView)
            NotificationCenter.default.post(name: .reportStatusDidChange, object: nil)
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func deleteReport(_ report: DomainPost) async {
        state.isLoading = true
        state.error = nil
        
        do {
            let input = DeleteReportInput(report: report)
            try await deleteReportUseCase.execute(input: input)
            
            // Удаляем отчет из списка
            state.reports.removeAll { $0.id == report.id }
            
            // Обновляем состояние кнопок
            updateButtonStates()
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    private func editReport(_ report: DomainPost) async {
        // TODO: Навигация к экрану редактирования
        // Пока просто логируем
        print("Edit report: \(report.id)")
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
            
            // Удаляем отчеты из списка
            state.reports.removeAll { state.selectedReportIDs.contains($0.id) }
            
            // Очищаем выбор
            state.selectedReportIDs.removeAll()
            state.isSelectionMode = false
            
            // Обновляем состояние кнопок
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
            Calendar.current.isDate(report.date, inSameDayAs: today) && !report.published
        }
        state.canCreateReport = !hasActiveReportToday
        
        // Можно отправить отчет, если есть неотправленные отчеты
        let hasUnsentReports = state.reports.contains { !$0.published }
        state.canSendReport = hasUnsentReports
    }
} 