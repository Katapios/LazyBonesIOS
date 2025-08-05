import Foundation
import UIKit

// Импорты для сервисов
import Combine

/// Контейнер зависимостей для Dependency Injection
class DependencyContainer {
    
    static let shared = DependencyContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    private init() {}
    
    // MARK: - Registration
    
    /// Зарегистрировать сервис как синглтон
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
        Logger.debug("Registered singleton: \(key)", log: Logger.general)
    }
    
    /// Зарегистрировать фабрику для создания сервиса
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        Logger.debug("Registered factory: \(key)", log: Logger.general)
    }
    
    // MARK: - Resolution
    
    /// Получить экземпляр сервиса
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        // Сначала проверяем синглтоны
        if let instance = services[key] as? T {
            return instance
        }
        
        // Затем проверяем фабрики
        if let factory = factories[key] {
            let instance = factory()
            if let typedInstance = instance as? T {
                Logger.debug("Resolved from factory: \(key)", log: Logger.general)
                return typedInstance
            }
        }
        
        Logger.warning("Failed to resolve: \(key)", log: Logger.general)
        return nil
    }
    
    /// Получить экземпляр сервиса или создать новый
    func resolveOrCreate<T>(_ type: T.Type) -> T {
        if let instance = resolve(type) {
            return instance
        }
        
        // Попытка создать экземпляр через инициализатор
        if let instance = createInstance(type) {
            register(type, instance: instance)
            return instance
        }
        
        fatalError("Cannot resolve or create instance of \(type)")
    }
    
    // MARK: - Cleanup
    
    /// Очистить все зарегистрированные сервисы
    func clear() {
        services.removeAll()
        factories.removeAll()
        Logger.info("Dependency container cleared", log: Logger.general)
    }
    
    /// Удалить конкретный сервис
    func remove<T>(_ type: T.Type) {
        let key = String(describing: type)
        services.removeValue(forKey: key)
        factories.removeValue(forKey: key)
        Logger.debug("Removed service: \(key)", log: Logger.general)
    }
    
    // MARK: - Private Methods
    
    private func createInstance<T>(_ type: T.Type) -> T? {
        // Здесь можно добавить логику создания экземпляров через reflection
        // Пока возвращаем nil
        return nil
    }
}

// MARK: - Convenience Extensions

extension DependencyContainer {
    
    /// Зарегистрировать основные сервисы приложения
    func registerCoreServices() {
        Logger.info("Registering core services", log: Logger.general)
        
        // UserDefaults Manager
        register(UserDefaultsManager.self, instance: UserDefaultsManager.shared)
        
        // Posts Provider (PostStore)
        register(PostsProviderProtocol.self, factory: {
            return PostStore.shared
        })
        
        // Notification Service
        register(NotificationServiceProtocol.self, factory: {
            NotificationService()
        })
        
        // Background Task Service
        register(BackgroundTaskServiceProtocol.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            let autoSendService = self.resolve(AutoSendServiceType.self)!
            return BackgroundTaskService(
                userDefaultsManager: userDefaultsManager,
                autoSendService: autoSendService
            )
        })
        
        // Telegram Service
        register(TelegramServiceProtocol.self, factory: {
            let token = UserDefaultsManager.shared.string(forKey: "telegramToken") ?? ""
            return TelegramService(token: token)
        })
        
        // Post-specific services
        register(PostTelegramServiceProtocol.self, factory: {
            let telegramService = self.resolve(TelegramServiceProtocol.self)!
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return PostTelegramService(telegramService: telegramService, userDefaultsManager: userDefaultsManager)
        })
        
        register(PostNotificationServiceProtocol.self, factory: {
            let notificationService = self.resolve(NotificationServiceProtocol.self)!
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return PostNotificationService(notificationService: notificationService, userDefaultsManager: userDefaultsManager)
        })
        
        // Telegram Integration Service
        register(TelegramIntegrationServiceType.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            let telegramService = self.resolve(TelegramServiceProtocol.self)
            return TelegramIntegrationService(
                userDefaultsManager: userDefaultsManager,
                telegramService: telegramService
            )
        })
        
        // Notification Manager Service
        register(NotificationManagerServiceType.self, factory: {
            let notificationService = self.resolve(NotificationServiceProtocol.self)!
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return NotificationManagerService(
                userDefaultsManager: userDefaultsManager,
                notificationService: notificationService
            )
        })
        
        // Auto Send Service
        register(AutoSendServiceType.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            let postTelegramService = self.resolve(PostTelegramServiceProtocol.self)!
            return AutoSendService(
                userDefaultsManager: userDefaultsManager,
                postTelegramService: postTelegramService
            )
        })
        
        // Use Cases
        register(CreateReportUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return CreateReportUseCase(postRepository: postRepository)
        })
        
        register(GetReportsUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return GetReportsUseCase(postRepository: postRepository)
        })
        
        register(DeleteReportUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return DeleteReportUseCase(postRepository: postRepository)
        })
        
        register(UpdateStatusUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            let settingsRepository = self.resolve(SettingsRepository.self)!
            return UpdateStatusUseCase(
                postRepository: postRepository,
                settingsRepository: settingsRepository
            )
        })

        register(UpdateReportUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return UpdateReportUseCase(postRepository: postRepository)
        })
        
        // Repositories
        register(PostRepository.self, factory: {
            let dataSource = self.resolve(UserDefaultsPostDataSource.self)!
            return PostRepository(dataSource: dataSource)
        })
        
        register(UserDefaultsPostDataSource.self, factory: {
            return UserDefaultsPostDataSource()
        })
        
        register(SettingsRepository.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return SettingsRepository(userDefaultsManager: userDefaultsManager)
        })
        
        // Timer Service
        register(PostTimerServiceProtocol.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return PostTimerService(
                userDefaultsManager: userDefaultsManager
            ) { timeLeft, progress in
                // Callback для обновления времени
                Logger.debug("Timer updated: \(timeLeft), progress: \(progress)", log: Logger.timer)
            }
        })
        
        // Protocol registrations for DI
        register(PostRepositoryProtocol.self, factory: {
            return self.resolve(PostRepository.self)!
        })
        
        register(SettingsRepositoryProtocol.self, factory: {
            return self.resolve(SettingsRepository.self)!
        })
        
        // Регистрируем конкретные типы вместо протоколов для избежания предупреждений Swift 6
        register(GetReportsUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return GetReportsUseCase(postRepository: postRepository)
        })
        
        register(UpdateStatusUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            let settingsRepository = self.resolve(SettingsRepository.self)!
            return UpdateStatusUseCase(
                postRepository: postRepository,
                settingsRepository: settingsRepository
            )
        })
        
        // iCloud Services
        registerICloudServices()
        
        Logger.info("Core services registered successfully", log: Logger.general)
    }
    
    /// Зарегистрировать Telegram сервис
    func registerTelegramService(token: String) {
        Logger.info("Registering Telegram service", log: Logger.general)
        
        let telegramService = TelegramService(token: token)
        register(TelegramServiceProtocol.self, instance: telegramService)
    }
    
    /// Зарегистрировать ViewModels для отчетов
    func registerReportViewModels() {
        Logger.info("Registering report ViewModels", log: Logger.general)
        
        // ViewModels будут создаваться напрямую в коде, где они нужны
        // так как они требуют MainActor и асинхронной инициализации
        
        Logger.info("Report ViewModels registration completed", log: Logger.general)
    }
    
    /// Зарегистрировать iCloud сервисы
    private func registerICloudServices() {
        Logger.info("Registering iCloud services", log: Logger.general)
        
        // ICloud File Manager
        register(ICloudFileManager.self, factory: {
            return ICloudFileManager()
        })
        
        // Report Formatter
        register(ReportFormatterProtocol.self, factory: {
            let deviceName = UIDevice.current.name
            let deviceIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            return ReportFormatter(deviceName: deviceName, deviceIdentifier: deviceIdentifier)
        })
        
        // ICloud Report Repository
        register(ICloudReportRepositoryProtocol.self, factory: {
            let fileManager = self.resolve(ICloudFileManager.self)!
            let formatter = self.resolve(ReportFormatterProtocol.self)!
            return ICloudReportRepository(fileManager: fileManager, reportFormatter: formatter)
        })
        
        // Export Reports Use Case
        register(ExportReportsUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            let iCloudRepository = self.resolve(ICloudReportRepositoryProtocol.self)!
            let formatter = self.resolve(ReportFormatterProtocol.self)!
            return ExportReportsUseCase(
                postRepository: postRepository,
                iCloudReportRepository: iCloudRepository,
                reportFormatter: formatter
            )
        })
        
        // Import iCloud Reports Use Case
        register(ImportICloudReportsUseCase.self, factory: {
            let iCloudRepository = self.resolve(ICloudReportRepositoryProtocol.self)!
            let formatter = self.resolve(ReportFormatterProtocol.self)!
            return ImportICloudReportsUseCase(
                iCloudReportRepository: iCloudRepository,
                reportFormatter: formatter
            )
        })
        
        // ICloud Service
        register(ICloudServiceProtocol.self, factory: {
            let exportUseCase = self.resolve(ExportReportsUseCase.self)!
            let importUseCase = self.resolve(ImportICloudReportsUseCase.self)!
            let iCloudRepository = self.resolve(ICloudReportRepositoryProtocol.self)!
            return ICloudService(
                exportUseCase: exportUseCase,
                importUseCase: importUseCase,
                iCloudReportRepository: iCloudRepository
            )
        })
        
        Logger.info("iCloud services registered successfully", log: Logger.general)
    }
} 