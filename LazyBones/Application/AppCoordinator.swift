import SwiftUI
import Foundation

/// Главный координатор приложения
class AppCoordinator: ObservableObject {
    
    @Published var currentTab: Tab = .main
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Tabs
    
    enum Tab: Int, CaseIterable {
        case main = 0
        case planning = 1
        case tags = 2
        case reports = 3
        case settings = 4
        
        var title: String {
            switch self {
            case .main:
                return "Главная"
            case .planning:
                return "План"
            case .tags:
                return "Теги"
            case .reports:
                return "Отчёты"
            case .settings:
                return "Настройки"
            }
        }
        
        var icon: String {
            switch self {
            case .main:
                return "house"
            case .planning:
                return "doc.text.below.ecg"
            case .tags:
                return "tag"
            case .reports:
                return "doc.text"
            case .settings:
                return "gear"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        Logger.info("AppCoordinator initialized", log: Logger.ui)
    }
    
    // MARK: - Navigation Methods
    
    /// Переключиться на указанную вкладку
    func switchToTab(_ tab: Tab) {
        currentTab = tab
        Logger.debug("Switched to tab: \(tab.title)", log: Logger.ui)
    }
    
    /// Навигация к указанному экрану
    func navigate(to destination: any Hashable) {
        navigationPath.append(destination)
        Logger.debug("Navigated to: \(destination)", log: Logger.ui)
    }
    
    /// Вернуться назад
    func navigateBack() {
        navigationPath.removeLast()
        Logger.debug("Navigated back", log: Logger.ui)
    }
    
    /// Вернуться к корню навигации
    func navigateToRoot() {
        navigationPath.removeLast(navigationPath.count)
        Logger.debug("Navigated to root", log: Logger.ui)
    }
    
    // MARK: - App Lifecycle
    
    /// Запуск приложения
    func start() {
        Logger.info("AppCoordinator started", log: Logger.ui)
        // Здесь можно добавить инициализацию сервисов, загрузку данных и т.д.
    }
    
    /// Остановка приложения
    func stop() {
        Logger.info("AppCoordinator stopped", log: Logger.ui)
        // Здесь можно добавить сохранение данных, очистку ресурсов и т.д.
    }
    
    // MARK: - Background Task Handling
    
    /// Обработка фоновых задач
    func handleBackgroundTask() {
        Logger.info("Handling background task", log: Logger.background)
        // Здесь можно добавить логику обработки фоновых задач
    }
    
    // MARK: - Widget Updates
    
    /// Обновление виджетов
    func updateWidgets() {
        Logger.debug("Updating widgets", log: Logger.ui)
        // Здесь можно добавить логику обновления виджетов
    }
} 