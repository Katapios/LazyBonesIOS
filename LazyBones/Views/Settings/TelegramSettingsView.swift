import SwiftUI

// Deprecated: настройки Telegram теперь инлайн в `SettingsView`.
@available(*, deprecated, message: "Not used; SettingsView inlines Telegram section")
struct TelegramSettingsView: View {
    @StateObject private var viewModel: SettingsViewModelNew

    init() {
        let container = DependencyContainer.shared
        self._viewModel = StateObject(wrappedValue: container.resolve(SettingsViewModelNew.self)!)
    }

    var body: some View {
        Form {
            Section(header: Text("Интеграция с Telegram")) {
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
        .navigationTitle("Telegram")
        .onAppear { Task { await viewModel.handle(.loadSettings) } }
    }
}

#Preview {
    TelegramSettingsView()
}
