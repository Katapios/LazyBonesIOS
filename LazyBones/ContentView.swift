//
//  ContentView.swift
//  LazyBones
//
//  Created by Денис Рюмин on 10.07.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("Главная", systemImage: "house")
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
    }
}

#Preview {
    ContentView()
}
