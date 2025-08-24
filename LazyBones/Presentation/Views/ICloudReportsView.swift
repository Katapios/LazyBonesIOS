import SwiftUI

/// View для отображения iCloud отчетов
struct ICloudReportsView: View {
    @StateObject var viewModel: ICloudReportsViewModel
    
    init(viewModel: ICloudReportsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            contentSection
        }
        .padding()
        .onAppear {
            Task { await viewModel.handle(.loadReports) }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ОТЧЕТЫ ИЗ ICLOUD")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    Task { await viewModel.handle(.refreshReports) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.state.isLoading)
            }
            
            // Информация о файле
            if viewModel.state.isICloudAvailable {
                fileInfoSection
            } else {
                iCloudUnavailableSection
            }
        }
    }
    
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(.blue)
                Text("Файл: LazyBonesReports.report")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
                Text("Размер: \(viewModel.state.formattedFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
                Text("Обновлено: \(viewModel.state.formattedLastRefresh)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var iCloudUnavailableSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("iCloud недоступен")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 16) {
            Group {
                if viewModel.state.isLoading {
                    loadingView
                } else if let error = viewModel.state.error {
                    errorView(error)
                } else if viewModel.state.hasReports {
                    reportsList
                } else {
                    emptyStateView
                }
            }
            
            // Информация о расположении файла
            //fileLocationInfoView
        }
    }
    
//    private var fileLocationInfoView: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Информация о файле:")
//                .font(.caption)
//                .fontWeight(.semibold)
//                .foregroundColor(.secondary)
//            
//            Text(viewModel.getFileLocationInfo())
//                .font(.caption2)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.leading)
//        }
//        .padding(.horizontal, 8)
//        .padding(.vertical, 4)
//        .background(Color(.systemGray6))
//        .cornerRadius(8)
//    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Загрузка отчетов...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Ошибка загрузки")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Повторить") {
                Task { await viewModel.handle(.refreshReports) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if !viewModel.state.isICloudAvailable {
                // iCloud недоступен
                Image(systemName: "icloud.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("iCloud недоступен")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Для синхронизации отчетов с другими пользователями необходимо:\n\n1. Войти в iCloud на устройстве\n2. Включить iCloud Drive\n3. Разрешить доступ к iCloud в настройках приложения")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                // iCloud доступен, но нет отчетов
                Image(systemName: "icloud.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text("Нет отчетов за сегодня")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("В iCloud файле нет отчетов за сегодня или файл пуст. Создайте отчеты и экспортируйте их в настройках.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if viewModel.state.isICloudAvailable {
                    Button("Обновить") {
                        Task { await viewModel.handle(.refreshReports) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Reports List
    
    private var reportsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Найдено отчетов: \(viewModel.state.reportsCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Удалить файл") {
                    Task { await viewModel.handle(.deleteFile) }
                }
                .font(.caption)
                .foregroundColor(.red)
                .disabled(viewModel.state.isLoading)
            }
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.state.reports) { report in
                        ICloudReportCardView(report: report)
                    }
                }
            }
        }
    }
}

// MARK: - ICloud Report Card View

struct ICloudReportCardView: View {
    let report: DomainICloudReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок с датой и устройством
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.date, style: .date)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(report.deviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(report.reportType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Содержимое отчета
            Text(report.reportContent)
                .font(.body)
                .lineLimit(6)
                .foregroundColor(.primary)
            
            // Время создания
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(report.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    let mockService = MockICloudService()
    let viewModel = ICloudReportsViewModel(iCloudService: mockService)
    
    return ICloudReportsView(viewModel: viewModel)
}

// MARK: - Mock Service for Preview

class MockICloudService: ICloudServiceProtocol {
    func exportReports(reportType: ICloudReportType, startDate: Date?, endDate: Date?, includeDeviceInfo: Bool, format: ReportFormat) async throws -> ExportReportsOutput {
        return ExportReportsOutput(success: true, exportedCount: 1)
    }
    
    func importReports(reportType: ICloudReportType, startDate: Date?, endDate: Date?, filterByDevice: String?) async throws -> ImportICloudReportsOutput {
        let mockReports = [
            DomainICloudReport(
                deviceName: "iPhone Дениса",
                deviceIdentifier: "test-id",
                reportContent: "✅ Хорошие дела:\n• Сделал зарядку\n• Прочитал книгу\n\n❌ Плохие дела:\n• Поздно лег спать",
                reportType: .regular
            )
        ]
        return ImportICloudReportsOutput(success: true, reports: mockReports, importedCount: 1)
    }
    
    func isICloudAvailable() async -> Bool {
        return true
    }
    
    func getFileInfo() async -> (url: URL?, size: Int64?) {
        return (URL(string: "file://test.report"), 1024)
    }
    
    func deleteFile() async throws {
        // Mock implementation
    }
    
    func getFileLocationInfo() -> String {
        return "📁 Папка: /Users/test/Library/Mobile Documents/com~apple~CloudDocs/LazyBonesReports\n📄 Файл: /Users/test/Library/Mobile Documents/com~apple~CloudDocs/LazyBonesReports/LazyBonesReports.report\n✅ Файл существует: true\n📊 Размер: 1024 байт\n📅 Создан: 2025-08-05 10:00:00 +0000\n🔄 Изменен: 2025-08-05 10:30:00 +0000"
    }
    
    func requestICloudAccess() async -> Bool {
        return true // Mock всегда возвращает true
    }
    
    func requestFileAccessPermissions() async -> Bool {
        return true // Mock всегда возвращает true
    }
    
    func createTestFileInAccessibleLocation() async -> Bool {
        return true // Mock всегда возвращает true
    }
} 
