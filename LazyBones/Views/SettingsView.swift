import SwiftUI
import WidgetKit

/// Вкладка 'Настройки': имя устройства для виджета и сброс отчётов
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var store: PostStore
    @State private var showAlert = false
    @State private var deviceName: String = ""
    @State private var showSaved = false
    @State private var telegramToken: String = ""
    @State private var telegramChatId: String = ""
    @State private var telegramBotId: String = ""
    @State private var telegramStatus: String? = nil
    @State private var showUnlockAlert = false
    // Новый раздел для проверки background fetch
    @State private var isBackgroundFetchTestEnabled: Bool = false
    var body: some View {
        Form {
            deviceNameSection
            telegramSection
            notificationSection
            autoSendSection
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
                store.clear()
                store.load()
                WidgetCenter.shared.reloadAllTimelines()
            }
            Button("Отмена", role: .cancel) {}
            Text("Все отчёты будут удалены безвозвратно.")
        }
        .alert("Разблокировать отчёты?", isPresented: $showUnlockAlert) {
            Button("Разблокировать", role: .destructive) {
                store.unlockReportCreation()
                store.updateReportStatus()
                WidgetCenter.shared.reloadAllTimelines()
            }
            Button("Отмена", role: .cancel) {}
            Text("Будет разблокирована возможность создания отчёта. Локальные отчёты не будут удалены.")
        }
        .onAppear {
            loadDeviceName()
            telegramToken = store.telegramToken ?? ""
            telegramChatId = store.telegramChatId ?? ""
            telegramBotId = store.telegramBotId ?? ""
            isBackgroundFetchTestEnabled = loadBackgroundFetchTestEnabled()
        }
        .onChange(of: isBackgroundFetchTestEnabled) { _, newValue in
            saveBackgroundFetchTestEnabled(newValue)
        }
        .hideKeyboardOnTap()
        .scrollIndicators(.hidden)
    }
    
    private var deviceNameSection: some View {
        Section(header: Text("Имя телефона для виджета")) {
            TextField("Введите имя телефона", text: $deviceName)
            Button("Сохранить имя") {
                saveDeviceName()
                showSaved = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if showSaved {
                Text("Сохранено!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var telegramSection: some View {
        Section(header: Text("Интеграция с группой в телеграмм")) {
            TextField("Токен Telegram-бота", text: $telegramToken)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("chat_id группы", text: $telegramChatId)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("ID бота (опционально)", text: $telegramBotId)
                .textContentType(.none)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .help("ID бота нужен для фильтрации и удаления только своих сообщений")
            Button("Сохранить Telegram-данные") {
                store.saveTelegramSettings(token: telegramToken.isEmpty ? nil : telegramToken, chatId: telegramChatId.isEmpty ? nil : telegramChatId, botId: telegramBotId.isEmpty ? nil : telegramBotId)
                telegramStatus = "Сохранено!"
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            Button("Проверить связь") {
                checkTelegramConnection()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
            if let status = telegramStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(status == "Успешно!" ? .green : .red)
            }
        }
    }
    
    private var notificationSection: some View {
        Section(header: Text("Настройка уведомлений")) {
            Toggle("Получать уведомления", isOn: $store.notificationsEnabled)
            if store.notificationsEnabled {
                Picker("Режим уведомлений", selection: $store.notificationMode) {
                    ForEach(NotificationMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode as NotificationMode)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    if store.notificationMode == .hourly {
                        Text("Уведомления каждый час с 8:00 до 21:00. Последнее уведомление в 21:00 — предостерегающее.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Уведомления только в 8:00 и 21:00. В 21:00 — предостерегающее.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let schedule = notificationScheduleForToday() {
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
            Toggle("Включить автоотправку отчетов", isOn: Binding(
                get: { store.autoSendService.autoSendEnabled },
                set: { newValue in
                    store.autoSendService.autoSendEnabled = newValue
                    store.autoSendService.saveAutoSendSettings()
                    store.autoSendService.scheduleAutoSendIfNeeded()
                }
            ))
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
    
    func saveDeviceName() {
        let userDefaults = AppConfig.sharedUserDefaults
        userDefaults.set(deviceName, forKey: "deviceName")
        userDefaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        loadDeviceName()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaved = false
        }
    }
    func loadDeviceName() {
        let userDefaults = AppConfig.sharedUserDefaults
        let name = userDefaults.string(forKey: "deviceName") ?? ""
        deviceName = name
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
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    telegramStatus = "Ошибка: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    telegramStatus = "Успешно!"
                } else {
                    telegramStatus = "Ошибка: неверный токен или chat_id"
                }
            }
        }
        task.resume()
    }
    func notificationScheduleForToday() -> String? {
        // Делегируем к notificationManagerService через PostStore
        return store.notificationManagerService.notificationScheduleForToday()
    }
    // --- UserDefaults для background fetch test ---
    private func saveBackgroundFetchTestEnabled(_ value: Bool) {
        let ud = AppConfig.sharedUserDefaults
        ud.set(value, forKey: "backgroundFetchTestEnabled")
    }
    private func loadBackgroundFetchTestEnabled() -> Bool {
        let ud = AppConfig.sharedUserDefaults
        return ud.bool(forKey: "backgroundFetchTestEnabled")
    }
}

#Preview {
    SettingsView().environmentObject(PostStore())
} 
