//
//  LazyBonesApp.swift
//  LazyBones
//
//  Created by Денис Рюмин on 10.07.2025.
//

import SwiftUI
import BackgroundTasks

@main
struct LazyBonesApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        Logger.info("App initializing", log: Logger.general)
        
        // Миграция статусов для обратной совместимости
        ReportStatusMigrator.performFullMigration()
        
        // Тестирование конфигурационных переменных
        #if DEBUG
        ConfigTest.testAllConfigVariables()
        ConfigTest.testWidgetConfigCompatibility()
        #endif
        
        // Инициализация DI контейнера
        setupDependencyInjection()
        
        // Регистрация фоновых задач
        setupBackgroundTasks()
        
        Logger.info("App initialization completed", log: Logger.general)
    }
}

// MARK: - Setup Methods

private func setupDependencyInjection() {
    Logger.info("Setting up dependency injection", log: Logger.general)
    
    let container = DependencyContainer.shared
    
    // Регистрация основных сервисов
    container.registerCoreServices()
    
    // Регистрация ViewModels
    container.registerReportViewModels()
    
    // Регистрация Telegram сервиса (если есть токен)
    let userDefaultsManager = UserDefaultsManager.shared
    let (token, _, _) = userDefaultsManager.loadTelegramSettings()
    if let token = token {
        container.registerTelegramService(token: token)
    }
    
    Logger.info("Dependency injection setup completed", log: Logger.general)
}

private func setupBackgroundTasks() {
    Logger.info("Setting up background tasks", log: Logger.general)
    
    do {
        let backgroundTaskService = DependencyContainer.shared.resolve(BackgroundTaskServiceProtocol.self)!
        try backgroundTaskService.registerBackgroundTasks()
        
        #if targetEnvironment(simulator)
        Logger.info("Skipping initial BGTask scheduling on Simulator", log: Logger.background)
        #else
        Task { @MainActor in
            // Schedule only if background refresh is available and auto-send is enabled
            let refreshStatus = UIApplication.shared.backgroundRefreshStatus
            if refreshStatus == .available,
               let autoSend = DependencyContainer.shared.resolve(AutoSendServiceType.self),
               autoSend.autoSendEnabled {
                do {
                    try backgroundTaskService.scheduleSendReportTask()
                } catch {
                    Logger.error("Failed to setup background tasks: \(error)", log: Logger.background)
                }
            } else {
                Logger.info("Skipping initial BGTask scheduling (refresh unavailable or auto-send disabled)", log: Logger.background)
            }
        }
        #endif
        Logger.info("Background tasks setup completed", log: Logger.general)
    } catch {
        Logger.error("Failed to setup background tasks: \(error)", log: Logger.background)
    }
}
