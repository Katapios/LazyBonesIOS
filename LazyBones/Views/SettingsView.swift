import SwiftUI
import WidgetKit

/// Вкладка 'Настройки': имя устройства для виджета и сброс отчётов
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel
    @State private var showAlert = false
    @State private var showUnlockAlert = false
    
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(store: store))
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .alert("Вы уверены?", isPresented: $showAlert) {
            Button("Удалить всё", role: .destructive) {
                viewModel.clearAllData()
            }
            Button("Отмена", role: .cancel) {}
            Text("Все отчёты будут удалены безвозвратно.")
        }
        .alert("Разблокировать отчёты?", isPresented: $showUnlockAlert) {
            Button("Разблокировать", role: .destructive) {
                viewModel.unlockReports()
            }
            Button("Отмена", role: .cancel) {}
            Text("Будет разблокирована возможность создания отчёта. Локальные отчёты не будут удалены.")
        }
        .onAppear {
            viewModel.loadSettings()
        }
        .onChange(of: viewModel.isBackgroundFetchTestEnabled) { _, newValue in
            viewModel.saveBackgroundFetchTestEnabled(newValue)
        }
        .hideKeyboardOnTap()
        .scrollIndicators(.hidden)
    }
    
    private var deviceNameSection: some View {
        Section(header: Text("Имя телефона для виджета")) {
            TextField("Введите имя телефона", text: $viewModel.deviceName)
            Button("Сохранить имя") {
                viewModel.saveDeviceName()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if viewModel.showSaved {
                Text("Сохранено!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var telegramSection: some View {
        Section(header: Text("Интеграция с группой в телеграмм")) {
            TextField("Токен Telegram-бота", text: $viewModel.telegramToken)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("chat_id группы", text: $viewModel.telegramChatId)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("ID бота (опционально)", text: $viewModel.telegramBotId)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .help("ID бота нужен для фильтрации и удаления только своих сообщений")
            Button("Сохранить Telegram-данные") {
                viewModel.saveTelegramSettings()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            Button("Проверить связь") {
                viewModel.checkTelegramConnection()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if let status = viewModel.telegramStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(status == "Успешно!" ? .green : .red)
            }
        }
    }
    
    private var notificationSection: some View {
        Section(header: Text("Настройка уведомлений")) {
            Toggle("Получать уведомления", isOn: viewModel.notificationsEnabled)
            if viewModel.store.notificationsEnabled {
                Picker("Режим уведомлений", selection: viewModel.notificationMode) {
                    ForEach(NotificationMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode as NotificationMode)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.store.notificationMode == .hourly {
                        Text("Уведомления каждый час с 8:00 до 21:00. Последнее уведомление в 21:00 — предостерегающее.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Уведомления только в 8:00 и 21:00. В 21:00 — предостерегающее.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let schedule = viewModel.notificationScheduleForToday() {
                        Text("Сегодня уведомления: ")
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
            Toggle("Включить автоотправку отчетов", isOn: viewModel.autoSendEnabled)
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
            if !viewModel.isICloudAvailable {
                // iCloud недоступен
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
                // iCloud доступен
                Button {
                    viewModel.exportToICloud()
                } label: {
                    HStack {
                        if viewModel.isExportingToICloud {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(viewModel.isExportingToICloud ? "Экспорт..." : "Экспортировать отчеты в iCloud")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.vertical, 4)
                .disabled(viewModel.isExportingToICloud)
                
                if let result = viewModel.exportResult {
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
                    viewModel.createTestFile()
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
    SettingsView(store: PostStore())
} 
