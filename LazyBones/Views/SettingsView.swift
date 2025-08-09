import SwiftUI
import WidgetKit

/// Вкладка 'Настройки': имя устройства для виджета и сброс отчётов
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModelNew
    @State private var showAlert = false
    @State private var showUnlockAlert = false
    
    init() {
        let container = DependencyContainer.shared
        self._viewModel = StateObject(wrappedValue: SettingsViewModelNew(
            settingsRepository: container.resolve(SettingsRepositoryProtocol.self)!,
            notificationManager: container.resolve(NotificationManagerServiceType.self)!,
            postRepository: container.resolve(PostRepositoryProtocol.self)!,
            timerService: container.resolve(PostTimerServiceProtocol.self)!,
            statusManager: ReportStatusManager(
                localService: LocalReportService.shared,
                timerService: container.resolve(PostTimerServiceProtocol.self)!,
                notificationService: container.resolve(PostNotificationServiceProtocol.self)!,
                postsProvider: container.resolve(PostsProviderProtocol.self)!,
                factory: ReportStatusFactory()
            ),
            iCloudService: container.resolve(ICloudServiceProtocol.self)!,
            autoSendService: container.resolve(AutoSendServiceType.self)!
        ))
    }
    var body: some View {
        Form {
            deviceNameSection
            telegramSection
            notificationSection
            autoSendSection
            iCloudSection
            dataSection
        }
        .navigationTitle("Настройки")
        .onChange(of: scenePhase, initial: false) { oldPhase, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .alert("Вы уверены?", isPresented: $showAlert) {
            Button("Удалить всё", role: .destructive) {
                Task { await viewModel.handle(.clearAllData) }
            }
            Button("Отмена", role: .cancel) {}
            Text("Все отчёты будут удалены безвозвратно.")
        }
        .alert("Разблокировать отчёты?", isPresented: $showUnlockAlert) {
            Button("Разблокировать", role: .destructive) {
                Task { await viewModel.handle(.unlockReports) }
            }
            Button("Отмена", role: .cancel) {}
            Text("Будет разблокирована возможность создания отчёта. Локальные отчёты не будут удалены.")
        }
        .onAppear {
            Task { await viewModel.handle(.loadSettings) }
        }
        .onChange(of: viewModel.state.isBackgroundFetchTestEnabled, initial: false) { _, newValue in
            Task { await viewModel.handle(.setBackgroundFetchTestEnabled(newValue)) }
        }
        .hideKeyboardOnTap()
        .scrollIndicators(.hidden)
    }
    
    private var deviceNameSection: some View {
        Section(header: Text("Имя телефона для виджета")) {
            TextField("Введите имя телефона", text: Binding(
                get: { viewModel.state.deviceName },
                set: { viewModel.state.deviceName = $0 }
            ))
            Button("Сохранить имя") {
                Task { await viewModel.handle(.saveDeviceName(viewModel.state.deviceName)) }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if viewModel.state.showSaved {
                Text("Сохранено!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var telegramSection: some View {
        Section(header: Text("Интеграция с группой в телеграмм")) {
            TextField("Токен Telegram-бота", text: Binding(
                get: { viewModel.state.telegramToken },
                set: { viewModel.state.telegramToken = $0 }
            ))
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("chat_id группы", text: Binding(
                get: { viewModel.state.telegramChatId },
                set: { viewModel.state.telegramChatId = $0 }
            ))
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("ID бота (опционально)", text: Binding(
                get: { viewModel.state.telegramBotId },
                set: { viewModel.state.telegramBotId = $0 }
            ))
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .help("ID бота нужен для фильтрации и удаления только своих сообщений")
            Button("Сохранить Telegram-данные") {
                Task {
                    await viewModel.handle(.saveTelegramSettings(
                        token: viewModel.state.telegramToken.isEmpty ? nil : viewModel.state.telegramToken,
                        chatId: viewModel.state.telegramChatId.isEmpty ? nil : viewModel.state.telegramChatId,
                        botId: viewModel.state.telegramBotId.isEmpty ? nil : viewModel.state.telegramBotId
                    ))
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            Button("Проверить связь") {
                Task { await viewModel.handle(.checkTelegramConnection) }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if let status = viewModel.state.telegramStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(status == "Успешно!" ? .green : .red)
            }
        }
    }
    
    private var notificationSection: some View {
        Section(header: Text("Настройка уведомлений")) {
            Toggle("Получать уведомления", isOn: Binding(
                get: { (viewModel.notificationManager as? NotificationManagerService)?.notificationsEnabled ?? false },
                set: { (viewModel.notificationManager as? NotificationManagerService)?.notificationsEnabled = $0 }
            ))
            if (viewModel.notificationManager as? NotificationManagerService)?.notificationsEnabled == true {
                Picker("Режим уведомлений", selection: Binding(
                    get: { (viewModel.notificationManager as? NotificationManagerService)?.notificationMode ?? .hourly },
                    set: { (viewModel.notificationManager as? NotificationManagerService)?.notificationMode = $0 }
                )) {
                    ForEach(NotificationMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode as NotificationMode)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ежечасные уведомления: каждый час с 8:00 до 21:00. В 21:00 — предостерегающее уведомление.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Два раза в день: в 8:00 и в 21:00 (в 21:00 — предостерегающее уведомление).")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let schedule = (viewModel.notificationManager as? NotificationManagerService)?.notificationScheduleForToday() {
                        Text("Сегодня уведомления:")
                            .font(.caption)
                        Text(schedule)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var autoSendSection: some View {
        Section(header: Text("Автоотправка отчетов")) {
            Toggle("Включить автоотправку отчетов", isOn: Binding(
                get: { viewModel.state.autoSendEnabled },
                set: { newValue in
                    viewModel.state.autoSendEnabled = newValue
                    (DependencyContainer.shared.resolve(AutoSendServiceType.self) as? AutoSendService)?.autoSendEnabled = newValue
                }
            ))
            DatePicker("Время автоотправки", selection: Binding(
                get: { viewModel.state.autoSendTime },
                set: { newDate in
                    viewModel.state.autoSendTime = newDate
                    (DependencyContainer.shared.resolve(AutoSendServiceType.self) as? AutoSendService)?.autoSendTime = newDate
                }
            ), displayedComponents: .hourAndMinute)
            if let status = viewModel.state.lastAutoSendStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Отчеты будут автоматически отправляться один раз в сутки, в период с 22:01 до 23:59. Если пользователь уже отправил отчеты вручную, автоотправка не производится. Если система не смогла отправить отчеты за предыдущие дни, они будут отправлены вместе с текущими. Отправка происходит в фоне, когда система разрешит выполнение фоновой задачи.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var dataSection: some View {
        Section(header: Text("Данные")) {
            Button(role: .destructive) {
                showAlert = true
            } label: {
                Text("Сбросить все локальные отчёты")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .padding(.vertical, 4)

            Button {
                showUnlockAlert = true
            } label: {
                Text("Разблокировать отчёты")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.vertical, 4)
        }
    }
    
    private var iCloudSection: some View {
        Section(header: Text("iCloud экспорт")) {
            if !viewModel.state.isICloudAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("iCloud недоступен")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    Text("Для синхронизации отчетов с другими пользователями необходимо:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Войти в iCloud на устройстве")
                        Text("• Включить iCloud Drive")
                        Text("• Разрешить доступ к iCloud в настройках приложения")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    Task { await viewModel.handle(.exportToICloud) }
                } label: {
                    HStack {
                        if viewModel.state.isExportingToICloud {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(viewModel.state.isExportingToICloud ? "Экспорт..." : "Экспортировать отчеты в iCloud")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.vertical, 4)
                .disabled(viewModel.state.isExportingToICloud)
                if let result = viewModel.state.exportResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("✅") ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Отчеты за сегодня будут сохранены в папку LazyBonesReports в iCloud Drive в формате, как в Telegram")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await viewModel.handle(.createTestFile) }
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Создать тестовый файл")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    SettingsView()
} 
