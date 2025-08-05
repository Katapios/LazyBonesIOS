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
    // Состояние для экспорта в iCloud
    @State private var isExportingToICloud = false
    @State private var exportResult: String? = nil
    @State private var isICloudAvailable = false
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
            checkICloudAvailability()
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
    
    private var iCloudSection: some View {
        Section(header: Text("iCloud экспорт")) {
            if !isICloudAvailable {
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
                    exportToICloud()
                } label: {
                    HStack {
                        if isExportingToICloud {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(isExportingToICloud ? "Экспорт..." : "Экспортировать отчеты в iCloud")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.vertical, 4)
                .disabled(isExportingToICloud)
                
                if let result = exportResult {
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
                    createTestFile()
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
