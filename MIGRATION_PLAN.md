# 🏗️ План миграции к Clean Architecture

## 📋 Обзор

Этот документ содержит пошаговый план миграции приложения LazyBones от текущей архитектуры к Clean Architecture. Миграция будет выполняться поэтапно, чтобы минимизировать риски и обеспечить стабильность приложения.

## 🎯 Цели миграции

- ✅ **Улучшить тестируемость** - каждый слой можно тестировать изолированно
- ✅ **Повысить поддерживаемость** - четкое разделение ответственности
- ✅ **Обеспечить масштабируемость** - легко добавлять новые функции
- ✅ **Упростить понимание кода** - четкая структура и зависимости

## 📊 Текущее состояние vs Целевое состояние

### 🔴 Текущая архитектура
```
LazyBones/
├── Models/          ← Смешанные модели и бизнес-логика
├── Views/           ← UI + логика
├── Core/
│   ├── Services/    ← Сервисы + репозитории
│   ├── Persistence/ ← Только UserDefaults
│   └── Common/      ← Утилиты
```

### ✅ Целевая архитектура
```
LazyBones/
├── Domain/          ← Бизнес-логика (самый внутренний слой)
├── Data/            ← Слой данных
├── Presentation/    ← Слой представления
└── Infrastructure/  ← Внешние зависимости
```

## 🚀 План миграции

### **ФАЗА 1: Подготовка и планирование (Неделя 1)**

#### 1.1 Анализ текущего кода
- [ ] Инвентаризация всех компонентов
- [ ] Выявление зависимостей между модулями
- [ ] Создание карты миграции

#### 1.2 Создание новой структуры папок
```
LazyBones/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   └── Repositories/
├── Data/
│   ├── Repositories/
│   ├── DataSources/
│   └── Models/
├── Presentation/
│   ├── ViewModels/
│   ├── Views/
│   └── Coordinators/
└── Infrastructure/
    ├── Services/
    ├── Persistence/
    └── DI/
```

#### 1.3 Настройка базовых протоколов
- [ ] Создать базовые протоколы для Use Cases
- [ ] Создать протоколы для репозиториев
- [ ] Обновить DI контейнер

### **ФАЗА 2: Domain Layer (Неделя 2-3)**

#### 2.1 Создание Domain Entities
```swift
// Domain/Entities/Post.swift
struct Post {
    let id: UUID
    let date: Date
    var goodItems: [String]
    var badItems: [String]
    var published: Bool
    var voiceNotes: [VoiceNote]
    var type: PostType
}

// Domain/Entities/ReportStatus.swift
enum ReportStatus {
    case notStarted, inProgress, sent, notCreated, notSent, done
}
```

#### 2.2 Создание Use Cases
```swift
// Domain/UseCases/CreateReportUseCase.swift
protocol CreateReportUseCaseProtocol {
    func execute(input: CreateReportInput) async throws -> Post
}

// Domain/UseCases/GetReportsUseCase.swift
protocol GetReportsUseCaseProtocol {
    func execute() async throws -> [Post]
}

// Domain/UseCases/UpdateStatusUseCase.swift
protocol UpdateStatusUseCaseProtocol {
    func execute() async throws -> ReportStatus
}
```

#### 2.3 Создание Repository интерфейсов
```swift
// Domain/Repositories/PostRepositoryProtocol.swift
protocol PostRepositoryProtocol {
    func save(_ post: Post) async throws
    func fetch() async throws -> [Post]
    func delete(_ post: Post) async throws
    func update(_ post: Post) async throws
}
```

### **ФАЗА 3: Data Layer (Неделя 4-5)**

#### 3.1 Создание Data Models
```swift
// Data/Models/PostDTO.swift
struct PostDTO: Codable {
    let id: String
    let date: String
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
    let voiceNotes: [VoiceNoteDTO]
    let type: String
}

// Data/Models/VoiceNoteDTO.swift
struct VoiceNoteDTO: Codable {
    let id: String
    let url: String
    let duration: Double
    let createdAt: String
}
```

#### 3.2 Создание Data Sources
```swift
// Data/DataSources/LocalDataSource.swift
protocol LocalDataSourceProtocol {
    func savePosts(_ posts: [PostDTO]) async throws
    func loadPosts() async throws -> [PostDTO]
    func saveTags(_ tags: [String], category: TagCategory) async throws
    func loadTags(category: TagCategory) async throws -> [String]
}

// Data/DataSources/RemoteDataSource.swift
protocol RemoteDataSourceProtocol {
    func sendToTelegram(_ message: String) async throws -> Bool
    func getUpdates() async throws -> [TelegramMessage]
}
```

#### 3.3 Реализация репозиториев
```swift
// Data/Repositories/PostRepositoryImpl.swift
class PostRepositoryImpl: PostRepositoryProtocol {
    private let localDataSource: LocalDataSourceProtocol
    private let remoteDataSource: RemoteDataSourceProtocol
    
    init(localDataSource: LocalDataSourceProtocol, remoteDataSource: RemoteDataSourceProtocol) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    func save(_ post: Post) async throws {
        let dto = post.toDTO()
        try await localDataSource.savePosts([dto])
    }
    
    func fetch() async throws -> [Post] {
        let dtos = try await localDataSource.loadPosts()
        return dtos.map { $0.toDomain() }
    }
}
```

### **ФАЗА 4: Presentation Layer (Неделя 6-7)**

#### 4.1 Создание ViewModels
```swift
// Presentation/ViewModels/ReportViewModel.swift
@MainActor
class ReportViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var reportStatus: ReportStatus = .notStarted
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let createReportUseCase: CreateReportUseCaseProtocol
    private let getReportsUseCase: GetReportsUseCaseProtocol
    private let updateStatusUseCase: UpdateStatusUseCaseProtocol
    
    init(
        createReportUseCase: CreateReportUseCaseProtocol,
        getReportsUseCase: GetReportsUseCaseProtocol,
        updateStatusUseCase: UpdateStatusUseCaseProtocol
    ) {
        self.createReportUseCase = createReportUseCase
        self.getReportsUseCase = getReportsUseCase
        self.updateStatusUseCase = updateStatusUseCase
    }
    
    func createReport(goodItems: [String], badItems: [String]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let input = CreateReportInput(
                goodItems: goodItems,
                badItems: badItems,
                voiceNotes: [],
                type: .regular
            )
            
            let post = try await createReportUseCase.execute(input: input)
            posts.append(post)
            await updateStatus()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateStatus() async {
        do {
            let status = try await updateStatusUseCase.execute()
            reportStatus = status
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### 4.2 Создание Coordinators
```swift
// Presentation/Coordinators/MainCoordinator.swift
protocol Coordinator: AnyObject {
    func start()
}

class MainCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let dependencyContainer: DependencyContainer
    
    init(navigationController: UINavigationController, dependencyContainer: DependencyContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        let viewModel = dependencyContainer.resolve(ReportViewModel.self)!
        let view = ReportFormView(viewModel: viewModel)
        navigationController.setViewControllers([view], animated: false)
    }
    
    func showReportForm() {
        let viewModel = dependencyContainer.resolve(ReportViewModel.self)!
        let view = ReportFormView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
    
    func showSettings() {
        let viewModel = dependencyContainer.resolve(SettingsViewModel.self)!
        let view = SettingsView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
}
```

### **ФАЗА 5: Infrastructure Layer (Неделя 8)**

#### 5.1 Миграция сервисов
```swift
// Infrastructure/Services/TelegramService.swift
class TelegramService: RemoteDataSourceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func sendToTelegram(_ message: String) async throws -> Bool {
        // Реализация отправки в Telegram
    }
    
    func getUpdates() async throws -> [TelegramMessage] {
        // Реализация получения обновлений
    }
}

// Infrastructure/Services/NotificationService.swift
class NotificationService {
    func scheduleNotifications() async throws {
        // Реализация планирования уведомлений
    }
    
    func cancelAllNotifications() {
        // Реализация отмены уведомлений
    }
}
```

#### 5.2 Обновление DI контейнера
```swift
// Infrastructure/DI/DependencyContainer.swift
extension DependencyContainer {
    func configure() {
        // Domain layer
        register(CreateReportUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            return CreateReportUseCase(repository: repository)
        }
        
        register(GetReportsUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            return GetReportsUseCase(repository: repository)
        }
        
        register(UpdateStatusUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            return UpdateStatusUseCase(repository: repository)
        }
        
        // Data layer
        register(PostRepositoryProtocol.self) { container in
            let localDataSource = container.resolve(LocalDataSourceProtocol.self)!
            let remoteDataSource = container.resolve(RemoteDataSourceProtocol.self)!
            return PostRepositoryImpl(
                localDataSource: localDataSource,
                remoteDataSource: remoteDataSource
            )
        }
        
        register(LocalDataSourceProtocol.self) { container in
            return LocalDataSourceImpl()
        }
        
        register(RemoteDataSourceProtocol.self) { container in
            let apiClient = container.resolve(APIClient.self)!
            return TelegramService(apiClient: apiClient)
        }
        
        // Presentation layer
        register(ReportViewModel.self) { container in
            let createUseCase = container.resolve(CreateReportUseCaseProtocol.self)!
            let getUseCase = container.resolve(GetReportsUseCaseProtocol.self)!
            let updateUseCase = container.resolve(UpdateStatusUseCaseProtocol.self)!
            
            return ReportViewModel(
                createReportUseCase: createUseCase,
                getReportsUseCase: getUseCase,
                updateStatusUseCase: updateUseCase
            )
        }
        
        // Infrastructure layer
        register(APIClient.self) { container in
            return APIClient()
        }
        
        register(NotificationService.self) { container in
            return NotificationService()
        }
    }
}
```

### **ФАЗА 6: Миграция Views (Неделя 9-10)**

#### 6.1 Обновление существующих Views
```swift
// Presentation/Views/ReportFormView.swift
struct ReportFormView: View {
    @StateObject var viewModel: ReportViewModel
    @State private var goodItems: [String] = [""]
    @State private var badItems: [String] = [""]
    
    var body: some View {
        VStack {
            // UI компоненты
            
            Button("Создать отчет") {
                Task {
                    await viewModel.createReport(
                        goodItems: goodItems.filter { !$0.isEmpty },
                        badItems: badItems.filter { !$0.isEmpty }
                    )
                }
            }
            .disabled(viewModel.isLoading)
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
```

#### 6.2 Создание новых Views
```swift
// Presentation/Views/ReportsListView.swift
struct ReportsListView: View {
    @StateObject var viewModel: ReportsListViewModel
    
    var body: some View {
        List(viewModel.posts) { post in
            ReportRowView(post: post)
        }
        .onAppear {
            Task {
                await viewModel.loadReports()
            }
        }
    }
}

// Presentation/Views/SettingsView.swift
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Telegram") {
                TextField("Bot Token", text: $viewModel.telegramToken)
                TextField("Chat ID", text: $viewModel.telegramChatId)
            }
            
            Section("Уведомления") {
                Toggle("Включить уведомления", isOn: $viewModel.notificationsEnabled)
                Picker("Режим", selection: $viewModel.notificationMode) {
                    ForEach(NotificationMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
}
```

### **ФАЗА 7: Тестирование (Неделя 11-12)**

#### 7.1 Unit тесты
```swift
// Tests/Domain/UseCases/CreateReportUseCaseTests.swift
class CreateReportUseCaseTests: XCTestCase {
    var useCase: CreateReportUseCase!
    var mockRepository: MockPostRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockPostRepository()
        useCase = CreateReportUseCase(repository: mockRepository)
    }
    
    func testCreateReport_Success() async throws {
        // Given
        let input = CreateReportInput(
            goodItems: ["Кодил"],
            badItems: ["Не гулял"],
            voiceNotes: [],
            type: .regular
        )
        
        // When
        let result = try await useCase.execute(input: input)
        
        // Then
        XCTAssertEqual(result.goodItems, ["Кодил"])
        XCTAssertEqual(result.badItems, ["Не гулял"])
        XCTAssertEqual(result.type, .regular)
        XCTAssertTrue(mockRepository.saveCalled)
    }
}

// Tests/Data/Repositories/PostRepositoryImplTests.swift
class PostRepositoryImplTests: XCTestCase {
    var repository: PostRepositoryImpl!
    var mockLocalDataSource: MockLocalDataSource!
    var mockRemoteDataSource: MockRemoteDataSource!
    
    override func setUp() {
        super.setUp()
        mockLocalDataSource = MockLocalDataSource()
        mockRemoteDataSource = MockRemoteDataSource()
        repository = PostRepositoryImpl(
            localDataSource: mockLocalDataSource,
            remoteDataSource: mockRemoteDataSource
        )
    }
    
    func testSavePost_Success() async throws {
        // Given
        let post = Post(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular)
        
        // When
        try await repository.save(post)
        
        // Then
        XCTAssertTrue(mockLocalDataSource.savePostsCalled)
    }
}

// Tests/Presentation/ViewModels/ReportViewModelTests.swift
@MainActor
class ReportViewModelTests: XCTestCase {
    var viewModel: ReportViewModel!
    var mockCreateUseCase: MockCreateReportUseCase!
    var mockGetUseCase: MockGetReportsUseCase!
    var mockUpdateUseCase: MockUpdateStatusUseCase!
    
    override func setUp() {
        super.setUp()
        mockCreateUseCase = MockCreateReportUseCase()
        mockGetUseCase = MockGetReportsUseCase()
        mockUpdateUseCase = MockUpdateStatusUseCase()
        viewModel = ReportViewModel(
            createReportUseCase: mockCreateUseCase,
            getReportsUseCase: mockGetUseCase,
            updateStatusUseCase: mockUpdateUseCase
        )
    }
    
    func testCreateReport_Success() async {
        // Given
        let expectedPost = Post(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: false, voiceNotes: [], type: .regular)
        mockCreateUseCase.result = expectedPost
        
        // When
        await viewModel.createReport(goodItems: ["Кодил"], badItems: [])
        
        // Then
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.posts.first?.goodItems, ["Кодил"])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}
```

#### 7.2 Integration тесты
```swift
// Tests/Integration/ReportFlowTests.swift
class ReportFlowTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    
    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
        dependencyContainer.configure()
    }
    
    func testCompleteReportFlow() async throws {
        // Given
        let viewModel = dependencyContainer.resolve(ReportViewModel.self)!
        
        // When
        await viewModel.createReport(goodItems: ["Кодил"], badItems: ["Не гулял"])
        
        // Then
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.reportStatus, .inProgress)
    }
}
```

#### 7.3 UI тесты
```swift
// Tests/UI/ReportFormUITests.swift
class ReportFormUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testCreateReportFlow() {
        // Given
        let goodItemTextField = app.textFields["goodItemTextField"]
        let badItemTextField = app.textFields["badItemTextField"]
        let createButton = app.buttons["createReportButton"]
        
        // When
        goodItemTextField.tap()
        goodItemTextField.typeText("Кодил")
        
        badItemTextField.tap()
        badItemTextField.typeText("Не гулял")
        
        createButton.tap()
        
        // Then
        XCTAssertTrue(app.staticTexts["Отчет создан"].exists)
    }
}
```

## 📋 Чек-лист миграции

### Фаза 1: Подготовка
- [ ] Создать новую структуру папок
- [ ] Настроить базовые протоколы
- [ ] Создать карту миграции

### Фаза 2: Domain Layer
- [ ] Создать Domain Entities
- [ ] Реализовать Use Cases
- [ ] Создать Repository интерфейсы

### Фаза 3: Data Layer
- [ ] Создать Data Models
- [ ] Реализовать Data Sources
- [ ] Создать Repository реализации

### Фаза 4: Presentation Layer
- [ ] Создать ViewModels
- [ ] Реализовать Coordinators
- [ ] Обновить DI контейнер

### Фаза 5: Infrastructure Layer
- [ ] Мигрировать сервисы
- [ ] Обновить DI контейнер
- [ ] Настроить зависимости

### Фаза 6: Views
- [ ] Обновить существующие Views
- [ ] Создать новые Views
- [ ] Протестировать UI

### Фаза 7: Тестирование
- [ ] Написать unit тесты
- [ ] Создать integration тесты
- [ ] Добавить UI тесты

## ⚠️ Риски и митигация

### Риски
1. **Нарушение функциональности** - миграция может сломать существующие функции
2. **Увеличение времени разработки** - миграция займет больше времени
3. **Сложность отладки** - новые слои могут усложнить отладку

### Митигация
1. **Поэтапная миграция** - мигрировать по одному компоненту
2. **Тестирование на каждом этапе** - писать тесты параллельно с миграцией
3. **Feature flags** - использовать feature flags для постепенного включения новой архитектуры
4. **Rollback план** - иметь план отката к предыдущей версии

## 📊 Метрики успеха

### Технические метрики
- [ ] Покрытие тестами > 80%
- [ ] Время сборки < 2 минут
- [ ] Размер приложения не увеличился > 10%

### Качественные метрики
- [ ] Количество багов уменьшилось
- [ ] Время разработки новых функций сократилось
- [ ] Код стал более читаемым

## 🎯 Следующие шаги

1. **Создать ветку для миграции** - `feature/clean-architecture-migration`
2. **Начать с Фазы 1** - подготовка и планирование
3. **Создать первый Use Case** - как proof of concept
4. **Провести code review** - убедиться в правильности подхода
5. **Продолжить поэтапную миграцию** - следуя плану

---

*План миграции создан: 3 августа 2025*
*Последнее обновление: 3 августа 2025* 