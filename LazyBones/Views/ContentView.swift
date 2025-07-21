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
            NavigationStack {
                MainView()
            }
            .tabItem {
                Label("Главная", systemImage: "house")
            }
            NavigationStack {
                DailyPlanningFormView()
            }
            .tabItem {
                Label("План", systemImage: "pencil.line")
            }
            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Отчёты", systemImage: "doc.text")
            }
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gear")
            }
        }
        .environmentObject(store)
        .onAppear {
            print("[DEBUG][ContentView] ContentView инициализирован, store: \(store)")
        }
        .onChange(of: scenePhase) {
            _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
} // ← Закрывающая скобка для ContentView

// PreviewProvider должен быть вне структуры ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
