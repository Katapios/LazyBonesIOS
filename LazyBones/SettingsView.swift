import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var store: PostStore
    @State private var showAlert = false
    @State private var deviceName: String = ""
    @State private var showSaved = false
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
                Section(header: Text("Данные")) {
                    Button(role: .destructive) {
                        showAlert = true
                    } label: {
                        Text("Сбросить все отчёты")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
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
            } message: {
                Text("Все отчёты будут удалены безвозвратно.")
            }
            .onAppear {
                loadDeviceName()
            }
        }
        .hideKeyboardOnTap()
    }
    func saveDeviceName() {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        userDefaults?.set(deviceName, forKey: "deviceName")
        userDefaults?.synchronize()
        print("[APP] Сохранили deviceName: \(deviceName)")
        WidgetCenter.shared.reloadAllTimelines()
        loadDeviceName()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaved = false
        }
    }
    func loadDeviceName() {
        let userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
        let name = userDefaults?.string(forKey: "deviceName") ?? ""
        print("[APP] Прочитали deviceName: \(name)")
        deviceName = name
    }
}

#Preview {
    SettingsView().environmentObject(PostStore())
} 