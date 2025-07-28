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
    @StateObject var appCoordinator = AppCoordinator()
    @StateObject var store = PostStore()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView(selection: $appCoordinator.currentTab) {
            NavigationStack(path: $appCoordinator.navigationPath) {
                MainView()
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
                TagManagerView()
            }
            .tabItem {
                Label(AppCoordinator.Tab.tags.title, systemImage: AppCoordinator.Tab.tags.icon)
            }
            .tag(AppCoordinator.Tab.tags)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                ReportsView()
            }
            .tabItem {
                Label(AppCoordinator.Tab.reports.title, systemImage: AppCoordinator.Tab.reports.icon)
            }
            .tag(AppCoordinator.Tab.reports)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                SettingsView()
            }
            .tabItem {
                Label(AppCoordinator.Tab.settings.title, systemImage: AppCoordinator.Tab.settings.icon)
            }
            .tag(AppCoordinator.Tab.settings)
        }
        .environmentObject(store)
        .onAppear {
            Logger.info("ContentView initialized", log: Logger.ui)
            appCoordinator.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Logger.debug("App became active, updating widgets", log: Logger.ui)
                WidgetCenter.shared.reloadAllTimelines()
                appCoordinator.updateWidgets()
            }
        }
        .onChange(of: appCoordinator.currentTab) { _, newTab in
            Logger.debug("Tab changed to: \(newTab.title)", log: Logger.ui)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppCoordinator())
    }
}
