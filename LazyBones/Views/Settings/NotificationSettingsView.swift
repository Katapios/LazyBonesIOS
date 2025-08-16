import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel: SettingsViewModelNew

    init() {
        let container = DependencyContainer.shared
        self._viewModel = StateObject(wrappedValue: container.resolve(SettingsViewModelNew.self)!)
    }

    var body: some View {
        Form {
            Section(header: Text("Уведомления")) {
                Toggle("Получать уведомления", isOn: Binding(
                    get: { viewModel.state.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))
                if viewModel.state.notificationsEnabled {
                    Picker("Режим уведомлений", selection: Binding(
                        get: { viewModel.state.notificationMode },
                        set: { viewModel.setNotificationMode($0) }
                    )) {
                        ForEach(NotificationMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode as NotificationMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 6) {
                        if viewModel.state.notificationMode == .hourly {
                            Text("Ежечасные уведомления: каждый час с 8:00 до 21:00. В 21:00 — предостерегающее уведомление.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("Два раза в день: в 8:00 и в 21:00 (в 21:00 — предостерегающее уведомление).")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
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
        .navigationTitle("Уведомления")
        .onAppear { Task { await viewModel.handle(.loadSettings) } }
    }
}

#Preview {
    NotificationSettingsView()
}
