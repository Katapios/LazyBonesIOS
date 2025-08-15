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
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard newPhase == .background else { return }
            Logger.info("Scene moved to background: attempting to (re)schedule BG task", log: Logger.background)
            #if !targetEnvironment(simulator)
            Task { @MainActor in
                let refreshStatus = UIApplication.shared.backgroundRefreshStatus
                if refreshStatus == .available,
                   let autoSend = DependencyContainer.shared.resolve(AutoSendServiceType.self),
                   autoSend.autoSendEnabled,
                   let backgroundTaskService = DependencyContainer.shared.resolve(BackgroundTaskServiceProtocol.self) {
                    do { try backgroundTaskService.scheduleSendReportTask() }
                    catch { Logger.error("Failed to schedule BG task on background: \(error)", log: Logger.background) }
                } else {
                    Logger.info("Skip scheduling on background (refresh unavailable or auto-send disabled)", log: Logger.background)
                }
            }
            #else
            Logger.info("Simulator: skip BG task scheduling on background transition", log: Logger.background)
            #endif
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
    
    // Регистрация Telegram сервиса через абстракцию (без прямого обращения к DI)
    let userDefaultsManager = UserDefaultsManager.shared
    let (token, _, _) = userDefaultsManager.loadTelegramSettings()
    if let updater = container.resolve(TelegramConfigUpdaterProtocol.self) {
        updater.applyTelegramToken(token)
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
