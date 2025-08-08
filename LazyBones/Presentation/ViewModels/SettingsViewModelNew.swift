import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class SettingsViewModelNew: BaseViewModel<SettingsState, SettingsEvent>, LoadableViewModel {
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // Dependencies
    private let settingsRepository: any SettingsRepositoryProtocol
    private let notificationManager: NotificationManagerServiceType
    private let postRepository: any PostRepositoryProtocol
    private let timerService: any PostTimerServiceProtocol
    private let statusManager: any ReportStatusManagerProtocol
    private let iCloudService: ICloudServiceProtocol

    init(
        settingsRepository: any SettingsRepositoryProtocol,
        notificationManager: NotificationManagerServiceType,
        postRepository: any PostRepositoryProtocol,
        timerService: any PostTimerServiceProtocol,
        statusManager: any ReportStatusManagerProtocol,
        iCloudService: ICloudServiceProtocol
    ) {
        self.settingsRepository = settingsRepository
        self.notificationManager = notificationManager
        self.postRepository = postRepository
        self.timerService = timerService
        self.statusManager = statusManager
        self.iCloudService = iCloudService
        super.init(initialState: SettingsState())
    }

    override func handle(_ event: SettingsEvent) async {
        switch event {
        case .loadSettings:
            await loadSettings()
        case let .saveDeviceName(name):
            await saveDeviceName(name)
        case let .saveTelegramSettings(token, chatId, botId):
            await saveTelegramSettings(token: token, chatId: chatId, botId: botId)
        case .checkTelegramConnection:
            await checkTelegramConnection()
        case .exportToICloud:
            await exportToICloud()
        case .createTestFile:
            await createTestFile()
        case .checkICloudAvailability:
            await checkICloudAvailability()
        case .clearAllData:
            await clearAllData()
        case .unlockReports:
            await unlockReports()
        case let .setBackgroundFetchTestEnabled(value):
            await setBackgroundFetchTestEnabled(value)
        }
    }

    // MARK: - Actions

    private func loadSettings() async {
        isLoading = true
        defer { isLoading = false }
        // Device
        state.deviceName = AppConfig.sharedUserDefaults.string(forKey: "deviceName") ?? ""
        // Telegram
        if let telegram = try? await settingsRepository.loadTelegramSettings() {
            state.telegramToken = telegram.token ?? ""
            state.telegramChatId = telegram.chatId ?? ""
            state.telegramBotId = telegram.botId ?? ""
        }
        // Background Fetch test flag
        state.isBackgroundFetchTestEnabled = AppConfig.sharedUserDefaults.bool(forKey: "backgroundFetchTestEnabled")
        // iCloud availability
        state.isICloudAvailable = await iCloudService.isICloudAvailable()
    }

    private func saveDeviceName(_ name: String) async {
        let ud = AppConfig.sharedUserDefaults
        ud.set(name, forKey: "deviceName")
        ud.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        state.deviceName = ud.string(forKey: "deviceName") ?? name
        state.showSaved = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state.showSaved = false
        }
    }

    private func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async {
        do {
            try await settingsRepository.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
            state.telegramStatus = "Сохранено!"
        } catch {
            state.telegramStatus = "Ошибка сохранения"
        }
    }

    private func checkTelegramConnection() async {
        guard !state.telegramToken.isEmpty, !state.telegramChatId.isEmpty else {
            state.telegramStatus = "Введите токен и chat_id"
            return
        }
        let urlString = "https://api.telegram.org/bot\(state.telegramToken)/sendMessage"
        let params = [
            "chat_id": state.telegramChatId,
            "text": "Проверка связи с LazyBones!"
        ]
        var urlComponents = URLComponents(string: urlString)
        urlComponents?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = urlComponents?.url else {
            state.telegramStatus = "Ошибка URL"
            return
        }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                state.telegramStatus = "Успешно!"
            } else {
                state.telegramStatus = "Ошибка: неверный токен или chat_id"
            }
        } catch {
            state.telegramStatus = "Ошибка: \(error.localizedDescription)"
        }
    }

    private func exportToICloud() async {
        state.isExportingToICloud = true
        state.exportResult = nil
        defer { state.isExportingToICloud = false }

        let hasFileAccess = await iCloudService.requestFileAccessPermissions()
        guard hasFileAccess else {
            state.exportResult = "❌ Нет разрешения на доступ к файлам. Проверьте настройки приложения."
            return
        }
        let hasICloudAccess = await iCloudService.requestICloudAccess()
        guard hasICloudAccess else {
            state.exportResult = "❌ Нет доступа к iCloud Drive. Проверьте настройки iCloud."
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
            state.exportResult = output.success ? "✅ Экспорт успешен: \(output.exportedCount) отчетов" : "❌ Ошибка: \(output.error?.localizedDescription ?? "Неизвестная ошибка")"
        } catch {
            if let exportError = error as? ExportReportsError {
                switch exportError {
                case .noReportsToExport:
                    state.exportResult = "⚠️ Нет отчетов за сегодня для экспорта"
                case .iCloudNotAvailable:
                    state.exportResult = "❌ iCloud недоступен"
                case .fileAccessDenied:
                    state.exportResult = "❌ Нет доступа к файлу"
                case .formattingError:
                    state.exportResult = "❌ Ошибка форматирования"
                case .unknown:
                    state.exportResult = "❌ Неизвестная ошибка"
                }
            } else {
                state.exportResult = "❌ Ошибка: \(error.localizedDescription)"
            }
        }
    }

    private func createTestFile() async {
        let success = await iCloudService.createTestFileInAccessibleLocation()
        state.exportResult = success ? "✅ Тестовый файл создан! Проверьте Desktop или Downloads" : "❌ Не удалось создать тестовый файл"
    }

    private func checkICloudAvailability() async {
        state.isICloudAvailable = await iCloudService.isICloudAvailable()
    }

    private func clearAllData() async {
        do {
            try await postRepository.clear()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error
        }
    }

    private func unlockReports() async {
        statusManager.unlockReportCreation()
        statusManager.updateStatus()
        timerService.updateReportStatus(statusManager.reportStatus)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func setBackgroundFetchTestEnabled(_ value: Bool) async {
        let ud = AppConfig.sharedUserDefaults
        ud.set(value, forKey: "backgroundFetchTestEnabled")
        state.isBackgroundFetchTestEnabled = value
    }
}