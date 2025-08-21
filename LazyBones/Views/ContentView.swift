//
//  ContentView.swift
//  LazyBones
//
//  Created by Денис Рюмин on 10.07.2025.
//

import SwiftUI
import WidgetKit
import Foundation

/// Корневой TabView приложения с новой архитектурой
struct ContentView: View {
    @StateObject var appCoordinator: AppCoordinator
    @StateObject var store = PostStore.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Создаем AppCoordinator с DI контейнером
        let dependencyContainer = DependencyContainer.shared
        self._appCoordinator = StateObject(wrappedValue: AppCoordinator(dependencyContainer: dependencyContainer))
    }
    
    var body: some View {
        TabView(selection: $appCoordinator.currentTab) {
            NavigationStack(path: $appCoordinator.navigationPath) {
                MainViewNew()
            }
            .tabItem {
                Label(AppCoordinator.Tab.main.title, systemImage: AppCoordinator.Tab.main.icon)
            }
            .tag(AppCoordinator.Tab.main)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                DailyPlanningFormView()
            }
            .tabItem {
                Label(AppCoordinator.Tab.planning.title, systemImage: AppCoordinator.Tab.planning.icon)
            }
            .tag(AppCoordinator.Tab.planning)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                TagManagerViewClean(
                    viewModel: DependencyContainer.shared.resolve(TagManagerViewModelNew.self)!
                )
            }
            .tabItem {
                Label(AppCoordinator.Tab.tags.title, systemImage: AppCoordinator.Tab.tags.icon)
            }
            .tag(AppCoordinator.Tab.tags)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                ReportsViewClean()
            }
            .tabItem {
                Label(AppCoordinator.Tab.reports.title, systemImage: AppCoordinator.Tab.reports.icon)
            }
            .tag(AppCoordinator.Tab.reports)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                appCoordinator.settingsRootView()
            }
            .tabItem {
                Label(AppCoordinator.Tab.settings.title, systemImage: AppCoordinator.Tab.settings.icon)
            }
            .tag(AppCoordinator.Tab.settings)
        }
        .environmentObject(store)
        .environmentObject(appCoordinator)
        .onAppear {
            Logger.info("ContentView initialized", log: Logger.ui)
            // Гарантированно загружаем данные до запуска координации и таймеров
            store.load()
            store.loadTelegramSettings()
            // Переинициализируем Telegram сервисы из DI, чтобы не требовать ручного сохранения настроек после перезапуска
            store.refreshTelegramServices()
            store.updateReportStatus()
            appCoordinator.start()
            // Перевод на CA по тегам: используем TagProvider как источник правды
            Task {
                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                await provider?.refresh()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Logger.debug("App became active, updating widgets", log: Logger.ui)
                // Обновляем Telegram настройки и сервисы при возврате из бэкграунда
                store.loadTelegramSettings()
                store.refreshTelegramServices()
                store.updateReportStatus()
                WidgetCenter.shared.reloadAllTimelines()
                appCoordinator.updateWidgets()
            }
        }
        .onChange(of: appCoordinator.currentTab) { _, newTab in
            Logger.debug("Tab changed to: \(newTab.title)", log: Logger.ui)
            // Включаем соответствующий координатор при переключении вкладки
            appCoordinator.switchToTab(newTab)
        }
        .overlay {
            if appCoordinator.isLoading {
                ProgressView("Загрузка...")
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("Ошибка", isPresented: .constant(appCoordinator.errorMessage != nil)) {
            Button("OK") {
                appCoordinator.clearError()
            }
        } message: {
            Text(appCoordinator.errorMessage ?? "")
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppCoordinator(dependencyContainer: DependencyContainer.shared))
    }
}
