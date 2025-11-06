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
    private let telegramConfigUpdater: TelegramConfigUpdaterProtocol
    private let telegramResolver: TelegramServiceResolverProtocol
    private let legacyUISync: LegacyUISyncProtocol

    init(
        settingsRepository: any SettingsRepositoryProtocol,
        notificationManager: NotificationManagerServiceType,
        postRepository: any PostRepositoryProtocol,
        timerService: any PostTimerServiceProtocol,
        statusManager: any ReportStatusManagerProtocol,
        iCloudService: ICloudServiceProtocol,
        autoSendService: AutoSendServiceType,
        telegramConfigUpdater: TelegramConfigUpdaterProtocol,
        telegramResolver: TelegramServiceResolverProtocol,
        legacyUISync: LegacyUISyncProtocol
    ) {
        self.settingsRepository = settingsRepository
        self.notificationManager = notificationManager
        self.postRepository = postRepository
        self.timerService = timerService
        self.statusManager = statusManager
        self.iCloudService = iCloudService
        self.autoSendService = autoSendService
        self.telegramConfigUpdater = telegramConfigUpdater
        self.telegramResolver = telegramResolver
        self.legacyUISync = legacyUISync
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
        case .unlockReports:
            await unlockReports()
        case .resetReportUnlock:
            await resetReportUnlock()
        case let .setBackgroundFetchTestEnabled(value):
            await setBackgroundFetchTestEnabled(value)
        }
    }

    // MARK: - Public setters for View bindings

    func setAutoSendEnabled(_ enabled: Bool) {
        // Обновляем только если значение изменилось
        if state.autoSendEnabled != enabled {
            state.autoSendEnabled = enabled
            autoSendService.autoSendEnabled = enabled
            autoSendService.scheduleAutoSendIfNeeded()
            // Обновляем статус только если он действительно изменился
            let newStatus = autoSendService.lastAutoSendStatus
            if state.lastAutoSendStatus != newStatus {
                state.lastAutoSendStatus = newStatus
            }
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        // Обновляем только если значение изменилось
        if state.notificationsEnabled != enabled {
            state.notificationsEnabled = enabled
            notificationManager.notificationsEnabled = enabled
            // Обновляем расписание после изменения настроек
            updateNotificationSchedule()
        }
    }

    func setNotificationMode(_ mode: NotificationMode) {
        // Обновляем только если значение изменилось
        if state.notificationMode != mode {
            state.notificationMode = mode
            notificationManager.notificationMode = mode
            // Обновляем расписание после изменения режима
            updateNotificationSchedule()
        }
    }
    
    private func updateNotificationSchedule() {
        if let notificationService = notificationManager as? NotificationManagerService {
            state.notificationSchedule = notificationService.notificationScheduleForToday()
        }
    }
    
    func setAutoSendTime(_ time: Date) {
        // Обновляем только если значение изменилось
        if state.autoSendTime != time {
            state.autoSendTime = time
            autoSendService.autoSendTime = time
            autoSendService.scheduleAutoSendIfNeeded()
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
        // AutoSend - читаем значения один раз, без подписки
        state.autoSendEnabled = autoSendService.autoSendEnabled
        state.autoSendTime = autoSendService.autoSendTime
        state.lastAutoSendStatus = autoSendService.lastAutoSendStatus
        // Notifications UI - читаем значения один раз, без подписки
        state.notificationsEnabled = notificationManager.notificationsEnabled
        state.notificationMode = notificationManager.notificationMode
        // Загружаем расписание уведомлений один раз
        if let notificationService = notificationManager as? NotificationManagerService {
            state.notificationSchedule = notificationService.notificationScheduleForToday()
        }
    }

    private func saveDeviceName(_ name: String) async {
        let ud = AppConfig.sharedUserDefaults
        ud.set(name, forKey: "deviceName")
        ud.synchronize()
        
        // Обновляем состояние только если значение изменилось
        let savedName = ud.string(forKey: "deviceName") ?? name
        if state.deviceName != savedName {
            state.deviceName = savedName
        }
        
        // Показываем статус сохранения
        state.showSaved = true
        
        // Перезагружаем виджеты только если имя действительно изменилось
        if state.deviceName != name {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        // Скрываем статус через 2 секунды
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state.showSaved = false
        }
    }

    private func saveTelegramSettings(token: String?, chatId: String?, botId: String?) async {
        do {
            try await settingsRepository.saveTelegramSettings(token: token, chatId: chatId, botId: botId)
            // Обновляем конфигурацию Telegram через абстракцию Infrastructure
            telegramConfigUpdater.applyTelegramToken(token)
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
            // Разрешаем сервис через тонкий адаптер, без прямого доступа к DI
            var telegramService = telegramResolver.resolveTelegramService()
            // Если сервис не зарегистрирован, но токен введён — зарегистрируем на лету
            if telegramService == nil {
                telegramConfigUpdater.applyTelegramToken(state.telegramToken)
                telegramService = telegramResolver.resolveTelegramService()
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


    private func unlockReports() async {
        statusManager.unlockReportCreation()
        WidgetCenter.shared.reloadAllTimelines()
        // Синхронизируем легаси UI через адаптер
        legacyUISync.syncReportStatusToLegacyUI()
        // Обновим состояние настроек, чтобы диагностические лейблы отобразили актуальные значения
        await loadSettings()
    }

    private func resetReportUnlock() async {
        // Сбрасываем принудительную разблокировку
        statusManager.forceUnlock = false
        legacyUISync.saveForceUnlock(false)
        // Пересчитываем статус и обновляем UI
        statusManager.updateStatus()
        legacyUISync.syncReportStatusToLegacyUI()
        WidgetCenter.shared.reloadAllTimelines()
        await loadSettings()
    }

    private func setBackgroundFetchTestEnabled(_ value: Bool) async {
        let ud = AppConfig.sharedUserDefaults
        ud.set(value, forKey: "backgroundFetchTestEnabled")
        state.isBackgroundFetchTestEnabled = value
    }
}