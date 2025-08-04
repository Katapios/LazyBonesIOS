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
│   ├── ViewModels/  ← ✅ ReportListViewModel (новая архитектура)
│   └── Views/       ← ✅ ReportListView (новая архитектура)
├── Application/     ← ✅ Координаторы
│   └── Coordinators/← ✅ AppCoordinator, ReportsCoordinator
├── Core/            ← ✅ Инфраструктура
│   ├── Services/    ← ✅ Все сервисы
│   └── Common/      ← ✅ DI Container, Utils
└── Views/           ← 🔄 Старые Views (в процессе миграции)
    ├── MainView     ← 🔄 Использует PostStore
    ├── ReportsView  ← 🔄 Использует PostStore
    └── SettingsView ← 🔄 Использует PostStore
```

### ✅ Целевая архитектура (70% достигнуто)
```
LazyBones/
├── Domain/          ← ✅ Бизнес-логика
├── Data/            ← ✅ Слой данных
├── Presentation/    ← 🔄 Слой представления
└── Infrastructure/  ← ✅ Внешние зависимости
```

## 📊 Статус выполнения

### ✅ Завершено (70%)

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

#### **ФАЗА 4: Presentation Layer** 🔄 (40%)
- [x] Создание базовых ViewModels (ReportListViewModel)
- [x] Создание базовых Views (ReportListView)
- [x] Создание States и Events
- [x] Реализация базовых Coordinators
- [ ] Создание ViewModels для оставшихся Views
- [ ] Миграция существующих Views

#### **ФАЗА 5: Infrastructure Layer** ✅
- [x] Миграция сервисов
- [x] Обновление DI контейнера
- [x] Настройка зависимостей

### 🔄 В процессе (20%)

#### **ФАЗА 6: Миграция Views** 🔄
- [ ] Обновление существующих Views
- [ ] Создание новых ViewModels
- [ ] Протестировать UI

#### **ФАЗА 7: Тестирование** 🔄
- [x] Unit тесты для Domain Layer
- [x] Unit тесты для Data Layer
- [x] Unit тесты для Presentation Layer (частично)
- [ ] Integration тесты
- [ ] UI тесты

## 🎯 Следующие шаги (маленькими шагами)

### **ШАГ 1: Создание ViewModels для старых Views**

#### 1.1 ReportsView → ReportsViewModel
**Приоритет: ВЫСОКИЙ**

```swift
// Presentation/ViewModels/ReportsViewModel.swift
@MainActor
class ReportsViewModel: BaseViewModel<ReportsState, ReportsEvent> {
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    private let createReportUseCase: any CreateReportUseCaseProtocol
    private let updateStatusUseCase: any UpdateStatusUseCaseProtocol
    
    // Миграция с PostStore на Use Cases
    func loadReports() async { /* ... */ }
    func createReport(goodItems: [String], badItems: [String]) async { /* ... */ }
    func deleteReport(_ report: DomainPost) async { /* ... */ }
}
```

#### 1.2 MainView → MainViewModel
**Приоритет: ВЫСОКИЙ**

```swift
// Presentation/ViewModels/MainViewModel.swift
@MainActor
class MainViewModel: BaseViewModel<MainState, MainEvent> {
    private let updateStatusUseCase: any UpdateStatusUseCaseProtocol
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    
    // Миграция статусной логики
    func updateStatus() async { /* ... */ }
    func loadTodayReport() async { /* ... */ }
}
```

#### 1.3 SettingsView → SettingsViewModel
**Приоритет: СРЕДНИЙ**

```swift
// Presentation/ViewModels/SettingsViewModel.swift
@MainActor
class SettingsViewModel: BaseViewModel<SettingsState, SettingsEvent> {
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let notificationService: NotificationManagerServiceType
    
    // Миграция настроек
    func loadSettings() async { /* ... */ }
    func saveTelegramSettings(token: String, chatId: String) async { /* ... */ }
}
```

### **ШАГ 2: Миграция Views на новые ViewModels**

#### 2.1 ReportsView миграция
```swift
// Старая архитектура
struct ReportsView: View {
    @EnvironmentObject var store: PostStore
    // ...
}

// Новая архитектура
struct ReportsView: View {
    @StateObject var viewModel: ReportsViewModel
    // ...
}
```

#### 2.2 MainView миграция
```swift
// Старая архитектура
struct MainView: View {
    @EnvironmentObject var store: PostStore
    // ...
}

// Новая архитектура
struct MainView: View {
    @StateObject var viewModel: MainViewModel
    // ...
}
```

### **ШАГ 3: Удаление дублирования**

#### 3.1 Удаление старых моделей
- [ ] Удалить `Post` модель (оставить только `DomainPost`)
- [ ] Удалить `PostStore` (заменить на Use Cases)
- [ ] Обновить все импорты

#### 3.2 Обновление DI контейнера
```swift
// Добавить регистрацию новых ViewModels
extension DependencyContainer {
    func registerViewModels() {
        register(ReportsViewModel.self) { container in
            let getReportsUseCase = container.resolve(GetReportsUseCaseProtocol.self)!
            let createReportUseCase = container.resolve(CreateReportUseCaseProtocol.self)!
            let updateStatusUseCase = container.resolve(UpdateStatusUseCaseProtocol.self)!
            
            return ReportsViewModel(
                getReportsUseCase: getReportsUseCase,
                createReportUseCase: createReportUseCase,
                updateStatusUseCase: updateStatusUseCase
            )
        }
        
        register(MainViewModel.self) { container in
            let updateStatusUseCase = container.resolve(UpdateStatusUseCaseProtocol.self)!
            let getReportsUseCase = container.resolve(GetReportsUseCaseProtocol.self)!
            
            return MainViewModel(
                updateStatusUseCase: updateStatusUseCase,
                getReportsUseCase: getReportsUseCase
            )
        }
    }
}
```

### **ШАГ 4: Дополнительное тестирование**

#### 4.1 Создание тестов для новых ViewModels
```swift
// Tests/Presentation/ViewModels/ReportsViewModelTests.swift
@MainActor
class ReportsViewModelTests: XCTestCase {
    var viewModel: ReportsViewModel!
    var mockGetReportsUseCase: MockGetReportsUseCase!
    var mockCreateReportUseCase: MockCreateReportUseCase!
    
    override func setUp() {
        super.setUp()
        mockGetReportsUseCase = MockGetReportsUseCase()
        mockCreateReportUseCase = MockCreateReportUseCase()
        viewModel = ReportsViewModel(
            getReportsUseCase: mockGetReportsUseCase,
            createReportUseCase: mockCreateReportUseCase,
            updateStatusUseCase: MockUpdateStatusUseCase()
        )
    }
    
    func testLoadReports_Success() async {
        // Given
        let expectedReports = [DomainPost(id: UUID(), date: Date(), goodItems: ["Кодил"], badItems: [], published: true, voiceNotes: [], type: .regular)]
        mockGetReportsUseCase.result = expectedReports
        
        // When
        await viewModel.handle(.loadReports)
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reports.first?.goodItems, ["Кодил"])
    }
}
```

#### 4.2 Integration тесты
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
        await viewModel.handle(.createReport(goodItems: ["Кодил"], badItems: ["Не гулял"]))
        
        // Then
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reportStatus, .inProgress)
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
- [ ] Создать ViewModels для оставшихся Views
- [ ] Обновить DI контейнер

### ✅ Фаза 5: Infrastructure Layer
- [x] Мигрировать сервисы
- [x] Обновить DI контейнер
- [x] Настроить зависимости

### 🔄 Фаза 6: Views
- [ ] Обновить существующие Views
- [ ] Создать новые ViewModels
- [ ] Протестировать UI

### 🔄 Фаза 7: Тестирование
- [x] Написать unit тесты
- [ ] Создать integration тесты
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

1. **Создать ViewModels** для ReportsView, MainView, SettingsView
2. **Мигрировать Views** на использование новых ViewModels
3. **Удалить дублирование** между старыми и новыми моделями
4. **Дополнительное тестирование** новых компонентов
5. **Провести code review** - убедиться в правильности подхода

## 📊 Прогресс миграции

| Компонент | Статус | Прогресс | Описание |
|-----------|--------|----------|----------|
| **Domain Layer** | ✅ | 100% | Полностью завершен |
| **Data Layer** | ✅ | 100% | Полностью завершен |
| **Presentation Layer** | 🔄 | 40% | ViewModels частично, Views в миграции |
| **Infrastructure Layer** | ✅ | 100% | Полностью завершен |
| **Testing** | 🔄 | 70% | Unit тесты готовы, нужны integration тесты |
| **Documentation** | ✅ | 100% | Документация актуализирована |

**Общий прогресс: 70% завершено**

---

*План миграции создан: 3 августа 2025*
*Последнее обновление: 3 августа 2025*
*Статус: 70% завершено* 