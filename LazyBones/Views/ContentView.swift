//
//  ContentView.swift
//  LazyBones
//
//  Created by Денис Рюмин on 10.07.2025.
//

import SwiftUI
import WidgetKit

/// Корневой TabView приложения
struct ContentView: View {
    @StateObject var store = PostStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("Главная", systemImage: "house")
                }
            DailyPlanningFormView()
                .tabItem {
                    Label("Планирование", systemImage: "pencil.line")
                }
            ReportsView()
                .tabItem {
                    Label("Отчёты", systemImage: "doc.text")
                }
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
        }
        .environmentObject(store)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

#Preview {
    ContentView()
}
