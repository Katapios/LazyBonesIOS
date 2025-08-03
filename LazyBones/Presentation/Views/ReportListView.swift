import SwiftUI

/// View для отображения списка отчетов
struct ReportListView: View {
    @StateObject var viewModel: ReportListViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.state.isLoading {
                    ProgressView("Загрузка отчетов...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.state.error {
                                ErrorView(error: error) {
                Task { await viewModel.handle(.refreshReports) }
            }
                } else if viewModel.state.hasReports {
                    reportList
                } else {
                    EmptyStateView()
                }
            }
            .navigationTitle("Отчеты")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Обновить") {
                        Task { await viewModel.handle(.refreshReports) }
                    }
                }
            }
        }
        .onAppear {
            Task { await viewModel.handle(.loadReports) }
        }
    }
    
    private var reportList: some View {
        List {
            ForEach(viewModel.state.filteredReports, id: \.id) { report in
                ReportRowView(report: report) {
                    Task { await viewModel.handle(.editReport(report)) }
                }
                .swipeActions(edge: .trailing) {
                    Button("Удалить", role: .destructive) {
                        Task { await viewModel.handle(.deleteReport(report)) }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.handle(.refreshReports)
        }
    }
}

/// View для отображения ошибки
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Произошла ошибка")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Повторить") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// View для пустого состояния
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Нет отчетов")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Создайте первый отчет, чтобы начать")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// View для строки отчета
struct ReportRowView: View {
    let report: DomainPost
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(report.date, style: .date)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(report.type.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                if !report.goodItems.isEmpty {
                    Text("Хорошее: \(report.goodItems.joined(separator: ", "))")
                        .font(.body)
                        .foregroundColor(.green)
                }
                
                if !report.badItems.isEmpty {
                    Text("Плохое: \(report.badItems.joined(separator: ", "))")
                        .font(.body)
                        .foregroundColor(.red)
                }
                
                if !report.voiceNotes.isEmpty {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("\(report.voiceNotes.count) голосовых заметок")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 