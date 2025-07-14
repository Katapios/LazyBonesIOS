import SwiftUI
import WidgetKit

/// Вкладка 'Настройки': имя устройства для виджета и сброс отчётов
struct SettingsView: View {
    @EnvironmentObject var store: PostStore
    @State private var showAlert = false
    @State private var deviceName: String = ""
    @State private var showSaved = false
    @State private var telegramToken: String = ""
    @State private var telegramChatId: String = ""
    @State private var telegramBotId: String = ""
    @State private var telegramStatus: String? = nil
    @State private var showUnlockAlert = false
    var body: some View {
        NavigationView {
            Form {
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
                Section(header: Text("Настройка уведомлений")) {
                    Toggle("Получать уведомления", isOn: $store.notificationsEnabled)
                    if store.notificationsEnabled {
                        Picker("Интервал уведомлений (часы)", selection: $store.notificationIntervalHours) {
                            ForEach(1...12, id: \.self) { hour in
                                Text("Каждые \(hour) ч.").tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
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
            .navigationTitle("Настройки")
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
            }
            .hideKeyboardOnTap()
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
}

#Preview {
    SettingsView().environmentObject(PostStore())
} 