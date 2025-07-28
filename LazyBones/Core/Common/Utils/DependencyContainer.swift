import Foundation

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
        
        // Notification Service
        register(NotificationServiceProtocol.self, factory: {
            NotificationService()
        })
        
        // Background Task Service
        register(BackgroundTaskServiceProtocol.self, factory: {
            BackgroundTaskService()
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
        
        Logger.info("Core services registered successfully", log: Logger.general)
    }
    
    /// Зарегистрировать Telegram сервис
    func registerTelegramService(token: String) {
        Logger.info("Registering Telegram service", log: Logger.general)
        
        let telegramService = TelegramService(token: token)
        register(TelegramServiceProtocol.self, instance: telegramService)
    }
} 