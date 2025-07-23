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
            backgroundFetchTestSection // Новый раздел
            dataSection
        }
        .navigationTitle("Настройки")
        .onChange(of: scenePhase, initial: false) { _, newPhase in
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
        .onChange(of: isBackgroundFetchTestEnabled) { newValue in
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
        Section(header: Text("Автоотправка отчета в Telegram")) {
            Toggle("Автоматически отправлять отчет", isOn: $store.autoSendToTelegram)
                .onChange(of: store.autoSendToTelegram) { store.saveAutoSendSettings() }
            if store.autoSendToTelegram && (store.telegramToken?.isEmpty ?? true || store.telegramChatId?.isEmpty ?? true) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Заполните токен и chat_id Telegram для автоотправки!")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            if store.autoSendToTelegram {
                DatePicker(
                    "Время отправки",
                    selection: Binding(
                        get: {
                            let cal = Calendar.current
                            let min = cal.date(bySettingHour: store.notificationStartHour, minute: 0, second: 0, of: Date()) ?? Date()
                            let max = cal.date(bySettingHour: store.notificationEndHour, minute: 0, second: 0, of: Date()) ?? Date()
                            if store.autoSendTime < min { return min }
                            if store.autoSendTime > max { return max }
                            return store.autoSendTime
                        },
                        set: { newValue in
                            let cal = Calendar.current
                            let min = cal.date(bySettingHour: store.notificationStartHour, minute: 0, second: 0, of: Date()) ?? Date()
                            let max = cal.date(bySettingHour: store.notificationEndHour, minute: 0, second: 0, of: Date()) ?? Date()
                            var value = newValue
                            if value < min { value = min }
                            if value > max { value = max }
                            store.autoSendTime = value
                            store.saveAutoSendSettings()
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .disabled(!store.autoSendToTelegram)
                .frame(maxHeight: 120)
                .clipped()
                .padding(.vertical, 4)
                Text("Время можно выбрать только с \(store.notificationStartHour):00 до \(store.notificationEndHour):00")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let status = store.lastAutoSendStatus {
                Text("Последняя отправка: \(status)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            // Новое предупреждение
            if store.autoSendToTelegram {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Автоотправка не сработает, если приложение было полностью выгружено из памяти. После запуска приложения перепланируйте автоотправку.")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Button("Перепланировать автоотправку") {
                        print("[DEBUG][SettingsView] Кнопка перепланирования автоотправки нажата")
                        PostStore.rescheduleBGTask()
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 4)

                    Button("Протестировать автоотправку") {
                        print("[DEBUG][SettingsView] Кнопка теста автоотправки нажата")
                        store.performAutoSendReport()
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // Новый раздел для проверки background fetch
    private var backgroundFetchTestSection: some View {
        Section(header: Text("Проверка background fetch")) {
            Toggle("Публиковать тестовое сообщение раз в полчаса", isOn: $isBackgroundFetchTestEnabled)
                .disabled(false)
            Text("Если включить этот ползунок, в Telegram-группу будет публиковаться тестовое сообщение каждые 30 минут. Функция работает только для тестирования background fetch и не влияет на обычную работу приложения.")
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
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        userDefaults?.set(deviceName, forKey: "deviceName")
        userDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        loadDeviceName()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaved = false
        }
    }
    func loadDeviceName() {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        let name = userDefaults?.string(forKey: "deviceName") ?? ""
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
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = urlComponents.url else {
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
        let calendar = Calendar.current
        let now = Date()
        let startHour = store.notificationStartHour
        let endHour = store.notificationEndHour
        var hours: [Int] = []
        switch store.notificationMode {
        case .hourly:
            hours = Array(stride(from: startHour, to: endHour, by: 1))
        case .twice:
            hours = [startHour, endHour - 1]
        }
        let currentHour = calendar.component(.hour, from: now)
        let todayHours = hours.filter { $0 > currentHour }
        guard !todayHours.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let today = calendar.startOfDay(for: now)
        let times = todayHours.map { hour -> String in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            return formatter.string(from: date)
        }
        return times.joined(separator: ", ")
    }
    // --- UserDefaults для background fetch test ---
    private func saveBackgroundFetchTestEnabled(_ value: Bool) {
        let ud = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        ud?.set(value, forKey: "backgroundFetchTestEnabled")
    }
    private func loadBackgroundFetchTestEnabled() -> Bool {
        let ud = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        return ud?.bool(forKey: "backgroundFetchTestEnabled") ?? false
    }
}

#Preview {
    SettingsView().environmentObject(PostStore())
} 
