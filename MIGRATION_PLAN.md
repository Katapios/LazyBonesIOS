# 🏗️ План миграции к Clean Architecture

## 📋 Обзор

Этот документ содержит пошаговый план миграции приложения LazyBones от текущей архитектуры к Clean Architecture. Миграция выполняется поэтапно, чтобы минимизировать риски и обеспечить стабильность приложения.

## 🎯 Цели миграции

- ✅ **Улучшить тестируемость** - каждый слой можно тестировать изолированно
- ✅ **Повысить поддерживаемость** - четкое разделение ответственности
- ✅ **Обеспечить масштабируемость** - легко добавлять новые функции
- ✅ **Упростить понимание кода** - четкая структура и зависимости

## 📊 Текущее состояние vs Целевое состояние

### 🔴 Текущая архитектура (частично мигрирована)
```
LazyBones/
├── Domain/          ← ✅ Бизнес-логика (самый внутренний слой)
│   ├── Entities/    ← ✅ DomainPost, DomainVoiceNote, ReportStatus
│   ├── UseCases/    ← ✅ CreateReportUseCase, GetReportsUseCase, etc.
│   └── Repositories/← ✅ PostRepositoryProtocol
├── Data/            ← ✅ Слой данных
│   ├── Repositories/← ✅ PostRepository, TagRepository
│   ├── DataSources/ ← ✅ UserDefaultsPostDataSource
│   └── Mappers/     ← ✅ PostMapper, VoiceNoteMapper
├── Presentation/    ← 🔄 Слой представления (частично)
│   ├── ViewModels/  ← 🔄 Смешанная архитектура
│   │   ├─ ✅ RegularReportsViewModel (новая архитектура)
│   │   ├─ ✅ CustomReportsViewModel (новая архитектура)
│   │   ├─ ✅ ExternalReportsViewModel (новая архитектура)
│   │   ├─ ✅ ReportListViewModel (новая архитектура)
│   │   ├─ 🔄 MainViewModel (адаптер PostStore)
│   │   ├─ 🔄 ReportsViewModel (адаптер PostStore)
│   │   ├─ 🔄 SettingsViewModel (адаптер PostStore)
│   │   └─ 🔄 TagManagerViewModel (адаптер PostStore)
│   └── Views/       ← 🔄 Смешанная архитектура
│       ├─ ✅ ExternalReportsView (новая архитектура)
│       ├─ 🔄 MainView (использует PostStore)
│       ├─ 🔄 ReportsView (использует PostStore)
│       └─ 🔄 SettingsView (использует PostStore)
├── Application/     ← ✅ Координаторы
│   └── Coordinators/← ✅ AppCoordinator, ReportsCoordinator
├── Core/            ← ✅ Инфраструктура
│   ├── Services/    ← ✅ Все сервисы
│   └── Common/      ← ✅ DI Container, Utils
└── Models/          ← 🔄 Старые модели (PostStore, Post)
    ├── PostStore    ← 🔄 Глобальное состояние (нужно удалить)
    └── Post         ← 🔄 Старая модель (нужно удалить)
```

### ✅ Целевая архитектура (65% достигнуто)
```
LazyBones/
├── Domain/          ← ✅ Бизнес-логика
├── Data/            ← ✅ Слой данных
├── Presentation/    ← 🔄 Слой представления
└── Infrastructure/  ← ✅ Внешние зависимости
```

## 📊 Статус выполнения

### ✅ Завершено (65%)

#### **ФАЗА 1: Подготовка и планирование** ✅
- [x] Инвентаризация всех компонентов
- [x] Выявление зависимостей между модулями
- [x] Создание карты миграции
- [x] Создание новой структуры папок
- [x] Настройка базовых протоколов

#### **ФАЗА 2: Domain Layer** ✅
- [x] Создание Domain Entities
- [x] Реализация Use Cases
- [x] Создание Repository интерфейсов

#### **ФАЗА 3: Data Layer** ✅
- [x] Создание Data Models
- [x] Реализация Data Sources
- [x] Создание Repository реализации
- [x] Создание Mappers

#### **ФАЗА 4: Presentation Layer** 🔄 (30% завершено)
- [x] Создание базовых ViewModels (ReportListViewModel)
- [x] Создание базовых Views (ReportListView)
- [x] Создание States и Events
- [x] Реализация базовых Coordinators
- [x] Создание RegularReportsViewModel (для обычных отчетов)
- [x] Создание CustomReportsViewModel (для кастомных отчетов)
- [x] Создание ExternalReportsViewModel (для внешних отчетов из Telegram)
- [x] Создание UpdateReportUseCase
- [x] Миграция External Reports на новую архитектуру
- [x] Исправление критических проблем с загрузкой сообщений из Telegram
- [x] Создание ExternalReportsView (единственный View с новой архитектурой)

#### **ФАЗА 5: Infrastructure Layer** ✅
- [x] Миграция сервисов
- [x] Обновление DI контейнера
- [x] Настройка зависимостей

### 🔄 В процессе (35%)

#### **ФАЗА 6: Миграция основных Views** 🔄 (КРИТИЧЕСКИЙ ПРИОРИТЕТ)
- [ ] Создание настоящих ViewModels для основных Views
- [ ] Миграция MainView на новую архитектуру
- [ ] Миграция ReportsView на новую архитектуру
- [ ] Миграция SettingsView на новую архитектуру
- [ ] Миграция TagManagerView на новую архитектуру

#### **ФАЗА 7: Рефакторинг PostStore** 🔄 (ВЫСОКИЙ ПРИОРИТЕТ)
- [ ] Замена PostStore на Use Cases в основных Views
- [ ] Удаление дублирующего кода
- [ ] Обновление зависимостей
- [ ] Удаление PostStore и Post моделей

#### **ФАЗА 8: Тестирование** ✅
- [x] Unit тесты для Domain Layer
- [x] Unit тесты для Data Layer
- [x] Unit тесты для Presentation Layer
- [x] Unit тесты для RegularReportsViewModel
- [x] Unit тесты для CustomReportsViewModel
- [x] Unit тесты для ExternalReportsViewModel

## 🚨 Критические проблемы

### 1. **Двойная архитектура**
```swift
// В одном приложении сосуществуют:
// НОВАЯ архитектура:
ExternalReportsView(viewModel: ExternalReportsViewModel) // ✅ Clean Architecture

// СТАРАЯ архитектура:
MainView(store: PostStore) // ❌ Прямая зависимость от PostStore
```

### 2. **PostStore как глобальное состояние**
```swift
// ContentView.swift
@StateObject var store = PostStore() // Глобальное состояние
.environmentObject(store) // Передается через Environment
```

### 3. **ViewModel-адаптеры вместо настоящих ViewModels**
```swift
// Вместо:
class MainViewModel: BaseViewModel<MainState, MainEvent> {
    private let updateStatusUseCase: any UpdateStatusUseCaseProtocol
    // ...
}

// Используется:
class MainViewModel: ObservableObject {
    @Published var store: PostStore // ❌ Адаптер, не ViewModel
}
```

## 🎯 Следующие шаги (маленькими шагами)

### **ШАГ 1: Создание настоящих ViewModels (Приоритет: ВЫСОКИЙ)**

#### 1.1 MainViewModel с новой архитектурой
```swift
// Presentation/ViewModels/MainViewModel.swift
@MainActor
class MainViewModel: BaseViewModel<MainState, MainEvent> {
    private let updateStatusUseCase: any UpdateStatusUseCaseProtocol
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    
    init(updateStatusUseCase: any UpdateStatusUseCaseProtocol,
         getReportsUseCase: any GetReportsUseCaseProtocol) {
        self.updateStatusUseCase = updateStatusUseCase
        self.getReportsUseCase = getReportsUseCase
        super.init(initialState: MainState())
    }
    
    override func handle(_ event: MainEvent) async {
        switch event {
        case .loadTodayReport:
            await loadTodayReport()
        case .updateStatus:
            await updateStatus()
        case .createReport:
            await createReport()
        }
    }
    
    private func loadTodayReport() async {
        state.isLoading = true
        do {
            let input = GetReportsInput(date: Date(), type: .regular)
            let reports = try await getReportsUseCase.execute(input: input)
            state.todayReport = reports.first
        } catch {
            state.error = error
        }
        state.isLoading = false
    }
}
```

#### 1.2 ReportsViewModel с новой архитектурой
```swift
// Presentation/ViewModels/ReportsViewModel.swift
@MainActor
class ReportsViewModel: BaseViewModel<ReportsState, ReportsEvent> {
    private let regularReportsVM: RegularReportsViewModel
    private let customReportsVM: CustomReportsViewModel
    private let externalReportsVM: ExternalReportsViewModel
    
    init(regularReportsVM: RegularReportsViewModel,
         customReportsVM: CustomReportsViewModel,
         externalReportsVM: ExternalReportsViewModel) {
        self.regularReportsVM = regularReportsVM
        self.customReportsVM = customReportsVM
        self.externalReportsVM = externalReportsVM
        super.init(initialState: ReportsState())
    }
    
    override func handle(_ event: ReportsEvent) async {
        switch event {
        case .loadAllReports:
            await loadAllReports()
        case .toggleSelectionMode:
            state.isSelectionMode.toggle()
        case .deleteSelectedReports:
            await deleteSelectedReports()
        }
    }
    
    private func loadAllReports() async {
        await regularReportsVM.handle(.loadReports)
        await customReportsVM.handle(.loadReports)
        await externalReportsVM.handle(.loadReports)
        
        state.regularReports = regularReportsVM.state.reports
        state.customReports = customReportsVM.state.reports
        state.externalReports = externalReportsVM.state.reports
    }
}
```

#### 1.3 SettingsViewModel с новой архитектурой
```swift
// Presentation/ViewModels/SettingsViewModel.swift
@MainActor
class SettingsViewModel: BaseViewModel<SettingsState, SettingsEvent> {
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let notificationService: NotificationManagerServiceType
    
    init(userDefaultsManager: UserDefaultsManagerProtocol,
         notificationService: NotificationManagerServiceType) {
        self.userDefaultsManager = userDefaultsManager
        self.notificationService = notificationService
        super.init(initialState: SettingsState())
    }
    
    override func handle(_ event: SettingsEvent) async {
        switch event {
        case .loadSettings:
            await loadSettings()
        case .saveTelegramSettings(let token, let chatId):
            await saveTelegramSettings(token: token, chatId: chatId)
        case .toggleNotifications(let enabled):
            await toggleNotifications(enabled: enabled)
        }
    }
}
```

### **ШАГ 2: Миграция Views на новые ViewModels**

#### 2.1 MainView миграция
```swift
// Старая архитектура
struct MainView: View {
    @StateObject var viewModel: MainViewModel
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: MainViewModel(store: store))
    }
}

// Новая архитектура
struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    
    init() {
        let container = DependencyContainer.shared
        self._viewModel = StateObject(wrappedValue: MainViewModel(
            updateStatusUseCase: container.resolve(UpdateStatusUseCaseProtocol.self)!,
            getReportsUseCase: container.resolve(GetReportsUseCaseProtocol.self)!
        ))
    }
}
```

#### 2.2 ReportsView миграция
```swift
// Старая архитектура
struct ReportsView: View {
    @StateObject var viewModel: ReportsViewModel
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: ReportsViewModel(store: store))
    }
}

// Новая архитектура
struct ReportsView: View {
    @StateObject private var viewModel: ReportsViewModel
    
    init() {
        let container = DependencyContainer.shared
        self._viewModel = StateObject(wrappedValue: ReportsViewModel(
            regularReportsVM: container.resolve(RegularReportsViewModel.self)!,
            customReportsVM: container.resolve(CustomReportsViewModel.self)!,
            externalReportsVM: container.resolve(ExternalReportsViewModel.self)!
        ))
    }
}
```

### **ШАГ 3: Обновление ContentView**

```swift
struct ContentView: View {
    @StateObject var appCoordinator: AppCoordinator
    // УДАЛИТЬ: @StateObject var store = PostStore()
    
    init() {
        let dependencyContainer = DependencyContainer.shared
        self._appCoordinator = StateObject(wrappedValue: AppCoordinator(dependencyContainer: dependencyContainer))
    }
    
    var body: some View {
        TabView(selection: $appCoordinator.currentTab) {
            NavigationStack(path: $appCoordinator.navigationPath) {
                MainView() // БЕЗ store!
            }
            .tabItem {
                Label(AppCoordinator.Tab.main.title, systemImage: AppCoordinator.Tab.main.icon)
            }
            .tag(AppCoordinator.Tab.main)
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                ReportsView() // БЕЗ store!
            }
            .tabItem {
                Label(AppCoordinator.Tab.reports.title, systemImage: AppCoordinator.Tab.reports.icon)
            }
            .tag(AppCoordinator.Tab.reports)
            
            // ... остальные табы
        }
        // УДАЛИТЬ: .environmentObject(store)
        .environmentObject(appCoordinator)
    }
}
```

### **ШАГ 4: Удаление дублирования**

#### 4.1 Удаление старых моделей
- [ ] Удалить `Post` модель (оставить только `DomainPost`)
- [ ] Удалить `PostStore` (заменить на Use Cases)
- [ ] Обновить все импорты

#### 4.2 Обновление DI контейнера
```swift
// Добавить регистрацию новых ViewModels
extension DependencyContainer {
    func registerViewModels() {
        register(MainViewModel.self) { container in
            let updateStatusUseCase = container.resolve(UpdateStatusUseCaseProtocol.self)!
            let getReportsUseCase = container.resolve(GetReportsUseCaseProtocol.self)!
            
            return MainViewModel(
                updateStatusUseCase: updateStatusUseCase,
                getReportsUseCase: getReportsUseCase
            )
        }
        
        register(ReportsViewModel.self) { container in
            let regularReportsVM = container.resolve(RegularReportsViewModel.self)!
            let customReportsVM = container.resolve(CustomReportsViewModel.self)!
            let externalReportsVM = container.resolve(ExternalReportsViewModel.self)!
            
            return ReportsViewModel(
                regularReportsVM: regularReportsVM,
                customReportsVM: customReportsVM,
                externalReportsVM: externalReportsVM
            )
        }
        
        register(SettingsViewModel.self) { container in
            let userDefaultsManager = container.resolve(UserDefaultsManagerProtocol.self)!
            let notificationService = container.resolve(NotificationManagerServiceType.self)!
            
            return SettingsViewModel(
                userDefaultsManager: userDefaultsManager,
                notificationService: notificationService
            )
        }
    }
}
```

### **ШАГ 5: Дополнительное тестирование**

#### 5.1 Создание тестов для новых ViewModels
```swift
// Tests/Presentation/ViewModels/MainViewModelTests.swift
@MainActor
class MainViewModelTests: XCTestCase {
    var viewModel: MainViewModel!
    var mockUpdateStatusUseCase: MockUpdateStatusUseCase!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    
    override func setUp() {
        super.setUp()
        mockUpdateStatusUseCase = MockUpdateStatusUseCase()
        mockGetReportsUseCase = MockGetReportsUseCase()
        viewModel = MainViewModel(
            updateStatusUseCase: mockUpdateStatusUseCase,
            getReportsUseCase: mockGetReportsUseCase
        )
    }
    
    func testLoadTodayReport_Success() async {
        // Given
        let expectedReport = DomainPost(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: true, voiceNotes: [], type: .regular)
        mockGetReportsUseCase.result = [expectedReport]
        
        // When
        await viewModel.handle(.loadTodayReport)
        
        // Then
        XCTAssertEqual(viewModel.state.todayReport?.id, expectedReport.id)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
}
```

#### 5.2 Integration тесты
```swift
// Tests/Integration/ReportFlowTests.swift
class ReportFlowTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    
    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
        dependencyContainer.registerCoreServices()
        dependencyContainer.registerViewModels()
    }
    
    func testCompleteReportFlow() async throws {
        // Given
        let viewModel = dependencyContainer.resolve(ReportsViewModel.self)!
        
        // When
        await viewModel.handle(.loadAllReports)
        
        // Then
        XCTAssertFalse(viewModel.state.regularReports.isEmpty)
        XCTAssertFalse(viewModel.state.customReports.isEmpty)
        XCTAssertFalse(viewModel.state.externalReports.isEmpty)
    }
}
```

## 📋 Чек-лист миграции

### ✅ Фаза 1: Подготовка
- [x] Создать новую структуру папок
- [x] Настроить базовые протоколы
- [x] Создать карту миграции

### ✅ Фаза 2: Domain Layer
- [x] Создать Domain Entities
- [x] Реализовать Use Cases
- [x] Создать Repository интерфейсы

### ✅ Фаза 3: Data Layer
- [x] Создать Data Models
- [x] Реализовать Data Sources
- [x] Создать Repository реализации

### 🔄 Фаза 4: Presentation Layer
- [x] Создать базовые ViewModels
- [x] Создать базовые Views
- [x] Реализовать базовые Coordinators
- [x] Создать ViewModels для всех типов отчетов
- [x] Мигрировать External Reports на новую архитектуру
- [x] Исправить критические проблемы с Telegram интеграцией
- [ ] Создать настоящие ViewModels для основных Views
- [ ] Мигрировать основные Views на новую архитектуру

### ✅ Фаза 5: Infrastructure Layer
- [x] Мигрировать сервисы
- [x] Обновить DI контейнер
- [x] Настроить зависимости

### 🔄 Фаза 6: Views
- [x] Обновить External Reports Views
- [ ] Обновить основные Views
- [ ] Протестировать UI

### 🔄 Фаза 7: PostStore Refactoring
- [ ] Заменить PostStore на Use Cases
- [ ] Удалить дублирующий код
- [ ] Обновить зависимости
- [ ] Удалить PostStore и Post модели

### ✅ Фаза 8: Тестирование
- [x] Написать unit тесты
- [x] Создать тесты для всех ViewModels
- [ ] Добавить UI тесты

## ⚠️ Риски и митигация

### Риски
1. **Нарушение функциональности** - миграция может сломать существующие функции
2. **Увеличение времени разработки** - миграция займет больше времени
3. **Сложность отладки** - новые слои могут усложнить отладку

### Митигация
1. **Поэтапная миграция** - мигрировать по одному компоненту ✅
2. **Тестирование на каждом этапе** - писать тесты параллельно с миграцией ✅
3. **Feature flags** - использовать feature flags для постепенного включения новой архитектуры
4. **Rollback план** - иметь план отката к предыдущей версии

## 📊 Метрики успеха

### Технические метрики
- [x] Покрытие тестами > 80% ✅
- [x] Время сборки < 2 минут ✅
- [x] Размер приложения не увеличился > 10% ✅

### Качественные метрики
- [x] Количество багов уменьшилось ✅
- [ ] Время разработки новых функций сократилось 🔄
- [x] Код стал более читаемым ✅

## 🎯 Следующие шаги

1. **Создать настоящие ViewModels** для MainView, ReportsView, SettingsView
2. **Мигрировать Views** на использование новых ViewModels
3. **Удалить PostStore** и заменить на Use Cases
4. **Дополнительное тестирование** новых компонентов
5. **Провести code review** - убедиться в правильности подхода

## 📊 Прогресс миграции

| Компонент | Статус | Прогресс | Описание |
|-----------|--------|----------|----------|
| **Domain Layer** | ✅ | 100% | Полностью завершен |
| **Data Layer** | ✅ | 100% | Полностью завершен |
| **Presentation Layer** | 🔄 | 30% | ViewModels готовы частично, Views в миграции |
| **Infrastructure Layer** | ✅ | 100% | Полностью завершен |
| **Testing** | 🔄 | 70% | Unit тесты готовы, нужны integration тесты |
| **Documentation** | ✅ | 100% | Документация актуализирована |

**Общий прогресс: 65% завершено**

---

*План миграции создан: 3 августа 2025*
*Последнее обновление: 5 августа 2025*
*Статус: 65% завершено* 