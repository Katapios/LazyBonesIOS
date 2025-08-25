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
        let isRunningTests = NSClassFromString("XCTestCase") != nil
        
        // UserDefaults Manager
        register(UserDefaultsManager.self, instance: UserDefaultsManager.shared)
        
        // Notification Service
        register(NotificationServiceProtocol.self, factory: {
            NotificationService()
        })
        
        // Telegram Service
        if isRunningTests {
            register(TelegramServiceProtocol.self, instance: TelegramServiceStub())
        } else {
            register(TelegramServiceProtocol.self, factory: {
                let token = UserDefaultsManager.shared.string(forKey: "telegramToken") ?? ""
                return TelegramService(token: token)
            })
        }
        
        // Post-specific services
        if isRunningTests {
            register(PostTelegramServiceProtocol.self, instance: PostTelegramServiceStub())
        } else {
            register(PostTelegramServiceProtocol.self, factory: {
                let telegramService = self.resolve(TelegramServiceProtocol.self)!
                let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
                return PostTelegramService(telegramService: telegramService, userDefaultsManager: userDefaultsManager)
            })
        }
        
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
        
        // Telegram Settings Repository & UseCases (Clean Architecture)
        register(TelegramSettingsRepository.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return TelegramSettingsRepositoryImpl(userDefaults: userDefaultsManager)
        })
        register(LoadTelegramSettingsUseCase.self, factory: {
            let repo = self.resolve(TelegramSettingsRepository.self)!
            return LoadTelegramSettingsUseCaseImpl(repository: repo)
        })
        register(SaveTelegramSettingsUseCase.self, factory: {
            let repo = self.resolve(TelegramSettingsRepository.self)!
            return SaveTelegramSettingsUseCaseImpl(repository: repo)
        })

        // External Posts Repository (UserDefaults-based)
        register(ExternalPostRepository.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return ExternalPostRepository(userDefaultsManager: userDefaultsManager)
        })
        register(ExternalPostRepositoryProtocol.self, factory: {
            return self.resolve(ExternalPostRepository.self)!
        })
        
        // Notification Manager Service
        if isRunningTests {
            register(NotificationManagerServiceType.self, instance: NotificationManagerServiceStub())
        } else {
            register(NotificationManagerServiceType.self, factory: {
                let notificationService = self.resolve(NotificationServiceProtocol.self)!
                let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
                return NotificationManagerService(
                    userDefaultsManager: userDefaultsManager,
                    notificationService: notificationService
                )
            })
        }
        
        // Auto Send Service
        if isRunningTests {
            register(AutoSendServiceType.self, instance: AutoSendServiceStub())
        } else {
            register(AutoSendServiceType.self, factory: {
                let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
                let postTelegramService = self.resolve(PostTelegramServiceProtocol.self)!
                return AutoSendService(
                    userDefaultsManager: userDefaultsManager,
                    postTelegramService: postTelegramService
                )
            })
        }
        
        // AutoSend Settings Repository & UseCases (Clean Architecture)
        register(AutoSendSettingsRepository.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return AutoSendSettingsRepositoryImpl(userDefaults: userDefaultsManager)
        })
        register(LoadAutoSendSettingsUseCase.self, factory: {
            let repo = self.resolve(AutoSendSettingsRepository.self)!
            return LoadAutoSendSettingsUseCaseImpl(repository: repo)
        })
        register(SaveAutoSendSettingsUseCase.self, factory: {
            let repo = self.resolve(AutoSendSettingsRepository.self)!
            return SaveAutoSendSettingsUseCaseImpl(repository: repo)
        })
        
        // Background Task Service (после регистрации AutoSend и зависимостей)
        register(BackgroundTaskServiceProtocol.self, instance: BackgroundTaskService.shared)
        
        // Telegram Config Updater
        register(TelegramConfigUpdaterProtocol.self, factory: {
            TelegramConfigUpdater(container: self)
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

        // Regular Report (CA) UseCases
        register(LoadRegularReportDraftUseCase.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return LoadRegularReportDraftUseCase(userDefaultsManager: userDefaultsManager)
        })
        register(SaveRegularReportDraftUseCase.self, factory: {
            let userDefaultsManager = self.resolve(UserDefaultsManager.self)!
            return SaveRegularReportDraftUseCase(userDefaultsManager: userDefaultsManager)
        })
        register(RemoveTodayRegularReportUseCase.self, factory: {
            let postsProvider = self.resolve(PostsProviderProtocol.self)!
            return RemoveTodayRegularReportUseCase(postsProvider: postsProvider)
        })
        register(SaveRegularReportAsLocalUseCase.self, factory: {
            let postsProvider = self.resolve(PostsProviderProtocol.self)!
            let postStore = PostStore.shared
            return SaveRegularReportAsLocalUseCase(postsProvider: postsProvider, postStore: postStore)
        })
        register(PublishRegularReportUseCase.self, factory: {
            let postsProvider = self.resolve(PostsProviderProtocol.self)!
            let postStore = PostStore.shared
            return PublishRegularReportUseCase(postsProvider: postsProvider, postStore: postStore)
        })

        // Plan Draft UseCases (Clean Architecture)
        register(LoadPlanDraftUseCase.self, factory: {
            let planningRepo = self.resolve(PlanningRepositoryProtocol.self)!
            return LoadPlanDraftUseCase(planningRepository: planningRepo)
        })
        register(SavePlanDraftUseCase.self, factory: {
            let planningRepo = self.resolve(PlanningRepositoryProtocol.self)!
            return SavePlanDraftUseCase(planningRepository: planningRepo)
        })
        register(CreateCustomReportFromDraftUseCase.self, factory: {
            let postRepository = self.resolve(PostRepositoryProtocol.self)!
            return CreateCustomReportFromDraftUseCase(postRepository: postRepository)
        })
        register(PublishCustomReportUseCase.self, factory: {
            let postRepository = self.resolve(PostRepositoryProtocol.self)!
            let telegramIntegration = self.resolve(TelegramIntegrationServiceType.self)!
            let postTelegramService = self.resolve(PostTelegramServiceProtocol.self)!
            return PublishCustomReportUseCase(
                postRepository: postRepository,
                telegramIntegration: telegramIntegration,
                postTelegramService: postTelegramService
            )
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
        
        register(TagRepository.self, factory: {
            return TagRepository(userDefaults: AppConfig.sharedUserDefaults)
        })
        
        // Planning Repository & DataSource
        register(PlanningLocalDataSource.self, factory: {
            return PlanningLocalDataSource()
        })
        
        register(PlanningRepository.self, factory: {
            let dataSource = self.resolve(PlanningLocalDataSource.self)!
            return PlanningRepository(dataSource: dataSource)
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
        
        register(TagRepositoryProtocol.self, factory: {
            return self.resolve(TagRepository.self)!
        })
        
        register(PlanningRepositoryProtocol.self, factory: {
            return self.resolve(PlanningRepository.self)!
        })
        
        // ReportStatusManager for DI (used by DailyReportCAViewModel)
        register((any ReportStatusManagerProtocol).self, factory: {
            let timerService = self.resolve(PostTimerServiceProtocol.self)!
            let notificationService = self.resolve(PostNotificationServiceProtocol.self)!
            let postsProvider = self.resolve(PostsProviderProtocol.self)!
            let manager: any ReportStatusManagerProtocol = ReportStatusManager(
                localService: LocalReportService.shared,
                timerService: timerService,
                notificationService: notificationService,
                postsProvider: postsProvider,
                factory: ReportStatusFactory()
            )
            return manager
        })

        // Telegram fetcher adapter for Domain
        register(TelegramFetcherProtocol.self, factory: {
            let integration = self.resolve(TelegramIntegrationServiceType.self)!
            return TelegramFetcherAdapter(integrationService: integration)
        })
        
        // Регистрируем конкретные типы вместо протоколов для избежания предупреждений Swift 6
        register(GetReportsUseCase.self, factory: {
            let postRepository = self.resolve(PostRepository.self)!
            return GetReportsUseCase(postRepository: postRepository)
        })
        
        // External reports UseCases
        register(GetExternalReportsUseCase.self, factory: {
            let repo = self.resolve(ExternalPostRepositoryProtocol.self)!
            return GetExternalReportsUseCase(repository: repo)
        })
        register(RefreshExternalReportsUseCase.self, factory: {
            let repo = self.resolve(ExternalPostRepositoryProtocol.self)!
            let fetcher = self.resolve(TelegramFetcherProtocol.self)!
            return RefreshExternalReportsUseCase(repository: repo, fetcher: fetcher)
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

        // File existence checker
        register(FileExistenceChecking.self, instance: DefaultFileExistenceChecker())

        // Posts Provider (PostStoreAdapter)
        // ВАЖНО: размещаем регистрацию в самом конце, чтобы PostStore.shared
        // создался после регистрации всех зависимостей (Telegram/Notifications/AutoSend и пр.)
        let postStoreAdapter = PostStoreAdapter()
        register(PostsProviderProtocol.self, instance: postStoreAdapter)
        // Регистрируем как any DomainPostsProviderProtocol для совместимости с Swift
        register((any DomainPostsProviderProtocol).self, instance: postStoreAdapter)

        Logger.info("Core services registered successfully", log: Logger.general)
    }

    /// Регистрация вспомогательных адаптеров для Presentation слоя
    @MainActor
    func registerPresentationAdapters() {
        // Разрешатель TelegramService без прямого доступа к DI из Presentation
        register(TelegramServiceResolverProtocol.self, factory: {
            TelegramServiceResolver()
        })
        // Адаптер синхронизации легаси UI (PostStore)
        register(LegacyUISyncProtocol.self, factory: {
            LegacyUISyncAdapter()
        })
        // SettingsViewModel фабрика (единая точка создания VM для Settings экранов)
        register(SettingsViewModelNew.self, factory: {
            let settingsRepository = self.resolve(SettingsRepositoryProtocol.self)!
            let notificationManager = self.resolve(NotificationManagerServiceType.self)!
            let postRepository = self.resolve(PostRepositoryProtocol.self)!
            let timerService = self.resolve(PostTimerServiceProtocol.self)!
            let statusManager: any ReportStatusManagerProtocol = ReportStatusManager(
                localService: LocalReportService.shared,
                timerService: timerService,
                notificationService: self.resolve(PostNotificationServiceProtocol.self)!,
                postsProvider: self.resolve(PostsProviderProtocol.self)!,
                factory: ReportStatusFactory()
            )
            let iCloudService = self.resolve(ICloudServiceProtocol.self)!
            let autoSendService = self.resolve(AutoSendServiceType.self)!
            let telegramConfigUpdater = self.resolve(TelegramConfigUpdaterProtocol.self)!
            let telegramResolver = self.resolve(TelegramServiceResolverProtocol.self)!
            let legacyUISync = self.resolve(LegacyUISyncProtocol.self)!
            return SettingsViewModelNew(
                settingsRepository: settingsRepository,
                notificationManager: notificationManager,
                postRepository: postRepository,
                timerService: timerService,
                statusManager: statusManager,
                iCloudService: iCloudService,
                autoSendService: autoSendService,
                telegramConfigUpdater: telegramConfigUpdater,
                telegramResolver: telegramResolver,
                legacyUISync: legacyUISync
            )
        })

        // ReportsViewModelNew фабрика (единая точка создания VM для Reports экрана)
        register(ReportsViewModelNew.self, factory: {
            let getReportsUseCase = self.resolve(GetReportsUseCase.self)!
            let deleteReportUseCase = self.resolve(DeleteReportUseCase.self)!
            let updateReportUseCase = self.resolve(UpdateReportUseCase.self)!
            let tagRepository = self.resolve(TagRepositoryProtocol.self)!
            return ReportsViewModelNew(
                getReportsUseCase: getReportsUseCase,
                deleteReportUseCase: deleteReportUseCase,
                updateReportUseCase: updateReportUseCase,
                tagRepository: tagRepository
            )
        })

        // TagManagerViewModelNew фабрика (единая точка создания VM для Tags экрана)
        register(TagManagerViewModelNew.self, factory: {
            let tagRepository = self.resolve(TagRepositoryProtocol.self)!
            return TagManagerViewModelNew(tagRepository: tagRepository)
        })

        // TagProvider для предоставления тегов в Presentation слое без PostStore (синглтон)
        do {
            let isRunningTests = NSClassFromString("XCTestCase") != nil
            if isRunningTests {
                register(TagProviderProtocol.self, instance: TagProviderStub())
            } else {
                let tagRepository = self.resolve(TagRepositoryProtocol.self)!
                let provider = DefaultTagProvider(repository: tagRepository)
                register(TagProviderProtocol.self, instance: provider)
            }
        }
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