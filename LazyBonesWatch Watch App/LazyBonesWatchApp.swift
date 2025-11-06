import SwiftUI

@main
struct LazyBonesWatchApp: App {
    @StateObject private var viewModel = WatchMainViewModel()
    
    init() {
        // Инициализируем WatchConnectivityService при запуске приложения
        // Это гарантирует, что сервис будет готов к получению данных
        _ = WatchConnectivityService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Принудительно обновляем данные при запуске
                    Task { @MainActor in
                        await viewModel.refreshData()
                    }
                }
        }
    }
}
