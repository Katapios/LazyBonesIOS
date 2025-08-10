import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class SettingsViewModelNew: BaseViewModel<SettingsState, SettingsEvent>, LoadableViewModel {
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // Dependencies
    private let settingsRepository: any SettingsRepositoryProtocol
    let notificationManager: NotificationManagerServiceType
    private let postRepository: any PostRepositoryProtocol
    private let timerService: any PostTimerServiceProtocol
    private let statusManager: any ReportStatusManagerProtocol
    private let iCloudService: ICloudServiceProtocol
    private let autoSendService: AutoSendServiceType

    init(
        settingsRepository: any SettingsRepositoryProtocol,
        notificationManager: NotificationManagerServiceType,
        postRepository: any PostRepositoryProtocol,
        timerService: any PostTimerServiceProtocol,
        statusManager: any ReportStatusManagerProtocol,
        iCloudService: ICloudServiceProtocol,
        autoSendService: AutoSendServiceType
    ) {
        self.settingsRepository = settingsRepository
        self.notificationManager = notificationManager
        self.postRepository = postRepository
        self.timerService = timerService
        self.statusManager = statusManager
        self.iCloudService = iCloudService
        self.autoSendService = autoSendService
        super.init(initialState: SettingsState())
    }

    func load() async {
        await handle(.loadSettings)
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

    // MARK: - Public setters for View bindings

    func setAutoSendEnabled(_ enabled: Bool) {
        state.autoSendEnabled = enabled
        autoSendService.autoSendEnabled = enabled
        autoSendService.scheduleAutoSendIfNeeded()
        state.lastAutoSendStatus = autoSendService.lastAutoSendStatus
    }

    func setAutoSendTime(_ date: Date) {
        state.autoSendTime = date
        autoSendService.autoSendTime = date
        autoSendService.scheduleAutoSendIfNeeded()
        state.lastAutoSendStatus = autoSendService.lastAutoSendStatus
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        state.notificationsEnabled = enabled
        (notificationManager as? NotificationManagerService)?.notificationsEnabled = enabled
    }

    func setNotificationMode(_ mode: NotificationMode) {
        state.notificationMode = mode
        (notificationManager as? NotificationManagerService)?.notificationMode = mode
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
        // AutoSend
        state.autoSendEnabled = autoSendService.autoSendEnabled
        state.autoSendTime = autoSendService.autoSendTime
        state.lastAutoSendStatus = autoSendService.lastAutoSendStatus
        // Notifications UI
        state.notificationsEnabled = (notificationManager as? NotificationManagerService)?.notificationsEnabled ?? false
        state.notificationMode = (notificationManager as? NotificationManagerService)?.notificationMode ?? .hourly
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
            // Обновляем TelegramService в DI, чтобы сразу подхватить новый токен
            let container = DependencyContainer.shared
            if let token = token, !token.isEmpty {
                container.registerTelegramService(token: token)
            } else {
                // Удаляем существующий сервис, чтобы последующие resolve получили пустой токен из UserDefaults
                container.remove(TelegramServiceProtocol.self)
            }
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
        do {
            // Разрешаем сервис через DI, чтобы соблюдать слои абстракции
            let container = DependencyContainer.shared
            var telegramService = container.resolve(TelegramServiceProtocol.self)
            // Если сервис не зарегистрирован, но токен введён — зарегистрируем на лету
            if telegramService == nil {
                container.registerTelegramService(token: state.telegramToken)
                telegramService = container.resolve(TelegramServiceProtocol.self)
            }
            guard let telegramService else {
                state.telegramStatus = "Сервис Telegram недоступен"
                return
            }
            // 1) Проверяем валидность токена (getMe)
            _ = try await telegramService.getMe()
            // 2) Пробуем отправить тестовое сообщение в указанный чат (как было в исходной логике)
            try await telegramService.sendMessage("Проверка связи с LazyBones!", to: state.telegramChatId)
            state.telegramStatus = "Успешно!"
        } catch {
            // Больше информации для пользователя
            if let apiErr = error as? APIClientError {
                switch apiErr {
                case .unauthorized:
                    state.telegramStatus = "Ошибка: неверный токен"
                case .forbidden, .notFound:
                    state.telegramStatus = "Ошибка: доступ запрещён или ресурс не найден"
                case .serverError(let code):
                    state.telegramStatus = "Ошибка сервера Telegram (\(code))"
                case .networkError(let underlying):
                    state.telegramStatus = "Сетевая ошибка: \(underlying.localizedDescription)"
                default:
                    state.telegramStatus = "Ошибка сети"
                }
            } else if let tgErr = error as? TelegramServiceError {
                switch tgErr {
                case .invalidToken:
                    state.telegramStatus = "Ошибка: неверный токен"
                case .invalidChatId:
                    state.telegramStatus = "Ошибка: неверный chat_id"
                case .apiError(let message):
                    state.telegramStatus = "Ошибка API: \(message)"
                case .networkError(let underlying):
                    state.telegramStatus = "Сетевая ошибка: \(underlying.localizedDescription)"
                default:
                    state.telegramStatus = tgErr.localizedDescription
                }
            } else if let urlErr = error as? URLError {
                state.telegramStatus = "Сетевая ошибка: \(urlErr.localizedDescription)"
            } else {
                state.telegramStatus = "Ошибка: \(error.localizedDescription)"
            }
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
        WidgetCenter.shared.reloadAllTimelines()
        // Синхронизируем легаси PostStore, чтобы UI обновился мгновенно
        PostStore.shared.updateReportStatus()
        // Обновим состояние настроек, чтобы диагностические лейблы отобразили актуальные значения
        await loadSettings()
    }

    private func setBackgroundFetchTestEnabled(_ value: Bool) async {
        let ud = AppConfig.sharedUserDefaults
        ud.set(value, forKey: "backgroundFetchTestEnabled")
        state.isBackgroundFetchTestEnabled = value
    }
}