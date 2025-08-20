import SwiftUI
import Foundation
import WidgetKit

/// Главный координатор приложения с поддержкой Clean Architecture
@MainActor
class AppCoordinator: BaseCoordinator, ObservableObject, ErrorHandlingCoordinator, LoadingCoordinator {
    
    // MARK: - Published Properties
    @Published var currentTab: Tab = .main
    @Published var navigationPath = NavigationPath()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let dependencyContainer: DependencyContainer
    private var currentChildCoordinator: Coordinator?
    
    // MARK: - Initialization
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
        Logger.info("AppCoordinator initialized", log: Logger.ui)
    }
    
    // MARK: - Tab Management
    func switchToTab(_ tab: Tab) {
        currentTab = tab
        
        // Очищаем текущий child coordinator
        if let currentChild = currentChildCoordinator {
            removeChildCoordinator(currentChild)
            currentChildCoordinator = nil
        }
        
        // Создаем новый coordinator для вкладки
        let coordinator = createCoordinator(for: tab)
        if let coordinator = coordinator {
            addChildCoordinator(coordinator)
            currentChildCoordinator = coordinator
            coordinator.start()
        }
        
        Logger.debug("Switched to tab: \(tab.title)", log: Logger.ui)
    }
    
    // MARK: - Coordinator Factory
    private func createCoordinator(for tab: Tab) -> Coordinator? {
        switch tab {
        case .main:
            return MainCoordinator(dependencyContainer: dependencyContainer)
        case .planning:
            return PlanningCoordinator(dependencyContainer: dependencyContainer)
        case .tags:
            return TagsCoordinator(dependencyContainer: dependencyContainer)
        case .reports:
            return ReportsCoordinator(dependencyContainer: dependencyContainer)
        case .settings:
            return SettingsCoordinator(dependencyContainer: dependencyContainer)
        }
    }
    
    // MARK: - Navigation with Error Handling
    func navigate(to destination: any Hashable) {
        navigationPath.append(destination)
        Logger.debug("Navigated to: \(destination)", log: Logger.ui)
    }
    
    func navigateBack() {
        navigationPath.removeLast()
        Logger.debug("Navigated back", log: Logger.ui)
    }
    
    func navigateToRoot() {
        navigationPath.removeLast(navigationPath.count)
        Logger.debug("Navigated to root", log: Logger.ui)
    }
    
    // MARK: - Error Handling
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        Logger.error("Navigation error: \(error)", log: Logger.ui)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Loading State
    func showLoading() {
        isLoading = true
    }
    
    func hideLoading() {
        isLoading = false
    }
    
    // MARK: - App Lifecycle with DI
    override func start() {
        Logger.info("AppCoordinator started", log: Logger.ui)
        
        // Инициализируем сервисы через DI и переключаем вкладку синхронно
        initializeServices()
        switchToTab(.main)
    }
    
    private func initializeServices() {
        showLoading()
        
        // Инициализируем необходимые сервисы
        let backgroundTaskService = dependencyContainer.resolve(BackgroundTaskServiceProtocol.self)
        do {
            try backgroundTaskService?.registerBackgroundTasks()
        } catch {
            handleError(error)
        }
        
        let notificationService = dependencyContainer.resolve(NotificationManagerServiceType.self)
        notificationService?.requestNotificationPermissionAndSchedule()
        
        hideLoading()
    }
    
    override func finish() {
        Logger.info("AppCoordinator stopped", log: Logger.ui)
        
        // Останавливаем все child coordinators
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
        
        // Сохраняем данные
        saveApplicationState()
    }
    
    private func saveApplicationState() {
        // Сохранение состояния приложения
        let userDefaultsManager = dependencyContainer.resolve(UserDefaultsManager.self)
        userDefaultsManager?.set(currentTab.rawValue, forKey: "lastActiveTab")
    }
    
    // MARK: - Background Task Handling
    func handleBackgroundTask() {
        Logger.info("Handling background task", log: Logger.background)
        
        Task {
            let autoSendService = dependencyContainer.resolve(AutoSendServiceType.self)
            autoSendService?.performAutoSendReport()
        }
    }
    
    // MARK: - Widget Updates
    func updateWidgets() {
        Logger.debug("Updating widgets", log: Logger.ui)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Root Views Factory
extension AppCoordinator {
    /// Корневой вью для вкладки "Настройки" через координатор/DI
    func settingsRootView() -> SettingsView {
        // При необходимости можно будет инстанцировать VM из DI и передать явно
        return SettingsView()
    }
}

// MARK: - Tabs

extension AppCoordinator {
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
}