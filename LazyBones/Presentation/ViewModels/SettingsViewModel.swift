import Foundation
import SwiftUI
import WidgetKit

/// ViewModel-адаптер для SettingsView, который оборачивает PostStore
/// Управляет настройками приложения, Telegram интеграцией, уведомлениями и iCloud
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var store: PostStore
    @Published var deviceName: String = ""
    @Published var showSaved: Bool = false
    @Published var telegramToken: String = ""
    @Published var telegramChatId: String = ""
    @Published var telegramBotId: String = ""
    @Published var telegramStatus: String? = nil
    @Published var isBackgroundFetchTestEnabled: Bool = false
    @Published var isExportingToICloud = false
    @Published var exportResult: String? = nil
    @Published var isICloudAvailable = false
    
    // MARK: - Initialization
    init(store: PostStore) {
        self.store = store
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        loadDeviceName()
        telegramToken = store.telegramToken ?? ""
        telegramChatId = store.telegramChatId ?? ""
        telegramBotId = store.telegramBotId ?? ""
        isBackgroundFetchTestEnabled = loadBackgroundFetchTestEnabled()
        checkICloudAvailability()
    }
    
    func saveDeviceName() {
        let userDefaults = AppConfig.sharedUserDefaults
        userDefaults.set(deviceName, forKey: "deviceName")
        userDefaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        loadDeviceName()
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showSaved = false
        }
    }
    
    private func loadDeviceName() {
        let userDefaults = AppConfig.sharedUserDefaults
        let name = userDefaults.string(forKey: "deviceName") ?? ""
        deviceName = name
    }
    
    // MARK: - Telegram Integration
    
    func saveTelegramSettings() {
        store.saveTelegramSettings(
            token: telegramToken.isEmpty ? nil : telegramToken,
            chatId: telegramChatId.isEmpty ? nil : telegramChatId,
            botId: telegramBotId.isEmpty ? nil : telegramBotId
        )
        telegramStatus = "Сохранено!"
    }
    
    func checkTelegramConnection() {
        guard let token = telegramToken.isEmpty ? nil : telegramToken,
              let chatId = telegramChatId.isEmpty ? nil : telegramChatId,
              !token.isEmpty, !chatId.isEmpty else {
            telegramStatus = "Введите токен и chat_id"
            return
        }
        
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        let message = "Проверка связи с LazyBones!"
        let params = [
            "chat_id": chatId,
            "text": message
        ]
        
        var urlComponents = URLComponents(string: urlString)
        urlComponents?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else {
            telegramStatus = "Ошибка URL"
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.telegramStatus = "Ошибка: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.telegramStatus = "Успешно!"
                } else {
                    self?.telegramStatus = "Ошибка: неверный токен или chat_id"
                }
            }
        }
        task.resume()
    }
    
    // MARK: - iCloud Integration
    
    func exportToICloud() {
        isExportingToICloud = true
        exportResult = nil
        
        Task {
            let iCloudService = DependencyContainer.shared.resolve(ICloudServiceProtocol.self)!
            
            // Сначала запрашиваем разрешения на доступ к файлам
            let hasFileAccess = await iCloudService.requestFileAccessPermissions()
            
            if !hasFileAccess {
                await MainActor.run {
                    exportResult = "❌ Нет разрешения на доступ к файлам. Проверьте настройки приложения."
                    isExportingToICloud = false
                }
                return
            }
            
            // Затем запрашиваем доступ к iCloud
            let hasICloudAccess = await iCloudService.requestICloudAccess()
            
            if !hasICloudAccess {
                await MainActor.run {
                    exportResult = "❌ Нет доступа к iCloud Drive. Проверьте настройки iCloud."
                    isExportingToICloud = false
                }
                return
            }
            
            do {
                let output = try await iCloudService.exportReports(
                    reportType: .today,
                    startDate: nil,
                    endDate: nil,
                    includeDeviceInfo: true,
                    format: .telegram
                )
                
                await MainActor.run {
                    if output.success {
                        exportResult = "✅ Экспорт успешен: \(output.exportedCount) отчетов"
                    } else {
                        exportResult = "❌ Ошибка: \(output.error?.localizedDescription ?? "Неизвестная ошибка")"
                    }
                    isExportingToICloud = false
                }
            } catch {
                await MainActor.run {
                    if let exportError = error as? ExportReportsError {
                        switch exportError {
                        case .noReportsToExport:
                            exportResult = "⚠️ Нет отчетов за сегодня для экспорта"
                        case .iCloudNotAvailable:
                            exportResult = "❌ iCloud недоступен"
                        case .fileAccessDenied:
                            exportResult = "❌ Нет доступа к файлу"
                        case .formattingError:
                            exportResult = "❌ Ошибка форматирования"
                        case .unknown:
                            exportResult = "❌ Неизвестная ошибка"
                        }
                    } else {
                        exportResult = "❌ Ошибка: \(error.localizedDescription)"
                    }
                    isExportingToICloud = false
                }
            }
        }
    }
    
    func createTestFile() {
        Task {
            let iCloudService = DependencyContainer.shared.resolve(ICloudServiceProtocol.self)!
            
            let success = await iCloudService.createTestFileInAccessibleLocation()
            
            await MainActor.run {
                if success {
                    exportResult = "✅ Тестовый файл создан! Проверьте Desktop или Downloads"
                } else {
                    exportResult = "❌ Не удалось создать тестовый файл"
                }
            }
        }
    }
    
    func checkICloudAvailability() {
        Task {
            let iCloudService = DependencyContainer.shared.resolve(ICloudServiceProtocol.self)!
            let available = await iCloudService.isICloudAvailable()
            await MainActor.run {
                isICloudAvailable = available
            }
        }
    }
    
    // MARK: - Data Management
    
    func clearAllData() {
        store.clear()
        store.load()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func unlockReports() {
        store.unlockReportCreation()
        store.updateReportStatus()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Notifications
    
    func notificationScheduleForToday() -> String? {
        return store.notificationManagerService.notificationScheduleForToday()
    }
    
    // MARK: - Background Fetch Test
    
    func saveBackgroundFetchTestEnabled(_ value: Bool) {
        let ud = AppConfig.sharedUserDefaults
        ud.set(value, forKey: "backgroundFetchTestEnabled")
    }
    
    private func loadBackgroundFetchTestEnabled() -> Bool {
        let ud = AppConfig.sharedUserDefaults
        return ud.bool(forKey: "backgroundFetchTestEnabled")
    }
    
    // MARK: - Computed Properties
    
    var notificationsEnabled: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.store.notificationsEnabled ?? false },
            set: { [weak self] newValue in self?.store.notificationsEnabled = newValue }
        )
    }
    
    var notificationMode: Binding<NotificationMode> {
        Binding(
            get: { [weak self] in self?.store.notificationMode ?? .hourly },
            set: { [weak self] newValue in self?.store.notificationMode = newValue }
        )
    }
    
    var autoSendEnabled: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.store.autoSendService.autoSendEnabled ?? false },
            set: { [weak self] newValue in
                guard let self = self else { return }
                self.store.autoSendService.autoSendEnabled = newValue
                self.store.autoSendService.saveAutoSendSettings()
                self.store.autoSendService.scheduleAutoSendIfNeeded()
            }
        )
    }
} 