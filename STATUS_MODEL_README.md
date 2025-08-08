# 📊 Статусная модель LazyBones

## Обзор

Статусная модель LazyBones - это централизованная система управления состоянием отчетов, которая определяет поведение UI, таймеров и автоматических процессов в приложении. Система поддерживает **3 различных типа отчетов**, каждый со своей логикой и ViewModels.

## 🎯 Основные принципы

### Единый источник истины
- Все статусы определены в `ReportStatus` enum
- Централизованное обновление через `ReportStatusManager.updateStatus()` (в `PostStore` — делегирование)
- Сервисы (`PostTimerService`, `NotificationManagerService`, виджеты) обновляются реактивно

### Реактивность
- Использование `@Published` для автоматического обновления UI
- Синхронизация с виджетами и уведомлениями
- Обновление таймеров в реальном времени

### Модульность
- Четкое разделение ответственности между компонентами
- Использование протоколов для тестируемости
- Dependency Injection для гибкости

## 📋 Типы отчетов

### 1. 🗓️ Regular Reports (Обычные отчеты)
- **Тип**: `.regular`
- **Структура**: `goodItems` + `badItems` + `voiceNotes`
- **Назначение**: Ежедневные отчеты о достижениях и неудачах
- **ViewModel**: `RegularReportsViewModel`
- **Функции**: Создание, редактирование, удаление, отправка

### 2. 📋 Custom Reports (Кастомные отчеты)
- **Тип**: `.custom`
- **Структура**: `goodItems` (план) + `evaluationResults` + `isEvaluated`
- **Назначение**: Планирование и оценка выполнения задач
- **ViewModel**: `CustomReportsViewModel`
- **Функции**: Создание, оценка выполнения, переоценка
- **Особенность**: Система оценки выполнения плана

### 3. 📨 External Reports (Внешние отчеты)
- **Тип**: `.external`
- **Источник**: Telegram Bot API
- **Структура**: `externalText`, `authorUsername`, `externalMessageId`
- **Назначение**: Отчеты, полученные из Telegram
- **ViewModel**: `ExternalReportsViewModel`
- **Функции**: Загрузка из Telegram, очистка истории

## 🏗️ Архитектура ViewModels

### Специализированные ViewModels

```swift
// Базовый протокол для всех отчетов
protocol ReportViewModelProtocol: ObservableObject {
    var reports: [DomainPost] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    func loadReports() async
    func deleteReport(_ report: DomainPost) async
}

// 1. Regular Reports ViewModel
@MainActor
class RegularReportsViewModel: BaseViewModel<RegularReportsState, RegularReportsEvent> {
    private let createReportUseCase: any CreateReportUseCaseProtocol
    private let getReportsUseCase: any GetReportsUseCaseProtocol
    private let deleteReportUseCase: any DeleteReportUseCaseProtocol
    
    func createReport(goodItems: [String], badItems: [String]) async
    func sendReport(_ report: DomainPost) async
    func editReport(_ report: DomainPost) async
}

// 2. Custom Reports ViewModel
@MainActor
class CustomReportsViewModel: BaseViewModel<CustomReportsState, CustomReportsEvent> {
    private let createReportUseCase: any CreateReportUseCaseProtocol
    private let updateReportUseCase: any UpdateReportUseCaseProtocol
    
    func createCustomReport(plan: [String]) async
    func evaluateReport(_ report: DomainPost, results: [Bool]) async
    func allowReevaluation(_ report: DomainPost) async
    func isEvaluationAllowed(_ report: DomainPost) -> Bool
}

// 3. External Reports ViewModel
@MainActor
class ExternalReportsViewModel: BaseViewModel<ExternalReportsState, ExternalReportsEvent> {
    private let telegramService: any TelegramServiceProtocol
    
    func reloadFromTelegram() async
    func clearHistory() async
    func openTelegramGroup() async
    func parseTelegramMessage(_ message: TelegramMessage) async
}

// Объединяющий ViewModel
@MainActor
class ReportsViewModel: BaseViewModel<ReportsState, ReportsEvent> {
    private let regularReportsVM: RegularReportsViewModel
    private let customReportsVM: CustomReportsViewModel
    private let externalReportsVM: ExternalReportsViewModel
    
    // Объединяет логику всех типов отчетов
    func loadAllReports() async
    func filterReports(by type: PostType?) async
    func handleSelectionMode() async
}
```

### States и Events для каждого типа

```swift
// Regular Reports
struct RegularReportsState {
    var reports: [DomainPost] = []
    var isLoading = false
    var error: Error? = nil
    var canCreateReport = true
    var canSendReport = false
}

enum RegularReportsEvent {
    case loadReports
    case createReport(goodItems: [String], badItems: [String])
    case sendReport(DomainPost)
    case deleteReport(DomainPost)
    case editReport(DomainPost)
}

// Custom Reports
struct CustomReportsState {
    var reports: [DomainPost] = []
    var isLoading = false
    var error: Error? = nil
    var allowReevaluation = false
    var evaluationInProgress = false
}

enum CustomReportsEvent {
    case loadReports
    case createCustomReport(plan: [String])
    case evaluateReport(DomainPost, results: [Bool])
    case toggleReevaluation(DomainPost)
    case deleteReport(DomainPost)
}

// External Reports
struct ExternalReportsState {
    var reports: [DomainPost] = []
    var isLoading = false
    var error: Error? = nil
    var isRefreshing = false
    var telegramConnected = false
}

enum ExternalReportsEvent {
    case loadReports
    case refreshFromTelegram
    case clearHistory
    case openTelegramGroup
    case handleTelegramMessage(TelegramMessage)
}
```

## 📋 Статусы отчетов

### Enum ReportStatus

```swift
enum ReportStatus: String, Codable, CaseIterable {
    case notStarted    // "Заполни отчет"
    case inProgress    // "Отчет заполняется..."
    case sent          // "Отчет отправлен"
    case notCreated    // "Отчёт не создан"
    case notSent       // "Отчёт не отправлен"
    case done          // "Завершен"
}
```

### Описание статусов

| Статус | Описание | Кнопка | Таймер | Период |
|--------|----------|--------|--------|--------|
| `notStarted` | Отчет не создан, период активен | "Создать отчет" (активна) | "До конца" | Активен |
| `inProgress` | Отчет сохранен, не отправлен | "Редактировать отчёт" (активна) | "До конца" | Активен |
| `sent` | Отчет отправлен в Telegram | "Создать отчет" (неактивна) | "До старта" | Любой |
| `notCreated` | Отчет не создан, период закончился | "Создать отчет" (неактивна) | "До старта" | Неактивен |
| `notSent` | Отчет создан, не отправлен, период закончился | "Создать отчет" (неактивна) | "До старта" | Неактивен |
| `done` | Устаревший статус | "Создать отчет" (неактивна) | "Завершено" | Любой |

## ⏰ Временные периоды

### Активный период
- **Время**: 8:00 - 22:00
- **Статусы**: `notStarted`, `inProgress`
- **Таймер**: "До конца" (показывает время до 22:00)

### Неактивный период
- **Время**: 22:00 - 8:00 (следующий день)
- **Статусы**: `notCreated`, `notSent`, `sent`
- **Таймер**: "До старта" (показывает время до 8:00 следующего дня)

## 🔄 Логика обновления статусов

### Основные правила

1. **Проверка нового дня**
   - При каждом обновлении проверяется, не наступил ли новый день
   - Если наступил новый день, статусы сбрасываются

2. **Определение статуса**
   ```swift
   if hasRegularReport {
       if isPeriodActive {
           return isReportPublished ? .sent : .inProgress
       } else {
           return isReportPublished ? .sent : .notSent
       }
   } else {
       return isPeriodActive ? .notStarted : .notCreated
   }
   ```

3. **Принудительная разблокировка**
   - Если `forceUnlock = true`, статус всегда `.notStarted`

### Автоматическое обновление

Статус обновляется автоматически при:
- Изменении отчетов (создание, сохранение, отправка)
- Изменении времени (переход между периодами)
- Изменении настроек
- Запуске приложения

## 🏗️ Архитектура

### Основные компоненты

#### 1. PostStore (Legacy - в процессе миграции)
```swift
class PostStore: ObservableObject {
    @Published var reportStatus: ReportStatus = .notStarted
    
    func updateReportStatus() {
        // Логика определения статуса
    }
    
    func checkForNewDay() {
        // Проверка нового дня
    }
}
```

#### 2. Специализированные ViewModels (Новая архитектура)
```swift
// RegularReportsViewModel
class RegularReportsViewModel: BaseViewModel<RegularReportsState, RegularReportsEvent> {
    func createReport(goodItems: [String], badItems: [String]) async {
        // Создание обычного отчета
    }
}

// CustomReportsViewModel
class CustomReportsViewModel: BaseViewModel<CustomReportsState, CustomReportsEvent> {
    func evaluateReport(_ report: DomainPost, results: [Bool]) async {
        // Оценка выполнения плана
    }
}

// ExternalReportsViewModel
class ExternalReportsViewModel: BaseViewModel<ExternalReportsState, ExternalReportsEvent> {
    func reloadFromTelegram() async {
        // Загрузка отчетов из Telegram
    }
}
```

#### 3. PostTimerService
```swift
class PostTimerService {
    func updateReportStatus(_ status: ReportStatus) {
        // Обновление таймера на основе статуса
    }
}
```

#### 4. UI компоненты
```swift
struct MainStatusBarView: View {
    var reportStatusText: String {
        switch store.reportStatus {
        case .notStarted: return "Заполни отчет!"
        case .inProgress: return "Отчет заполняется..."
        // ...
        }
    }
}
```

### Схема взаимодействия (Обновленная)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  ReportsView                │  ReportsViewModel            │
│  ├─ RegularReportsSection   │  ├─ RegularReportsViewModel  │
│  ├─ CustomReportsSection    │  ├─ CustomReportsViewModel   │
│  └─ ExternalReportsSection  │  └─ ExternalReportsViewModel │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Use Cases                  │  Repository Protocols        │
│  ├─ CreateReportUseCase     │  ├─ PostRepositoryProtocol   │
│  ├─ GetReportsUseCase       │  └─ TagRepositoryProtocol    │
│  ├─ UpdateReportUseCase     │                              │
│  └─ DeleteReportUseCase     │                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  Repositories               │  Services                    │
│  ├─ PostRepository          │  ├─ TelegramService          │
│  └─ TagRepository           │  └─ PostTimerService         │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Конфигурация

### ReportStatusConfig

```swift
struct ReportStatusConfig {
    struct TimeSettings {
        let startHour: Int      // 8
        let endHour: Int        // 22
        let timeZone: TimeZone  // .current
    }
    
    struct StatusSettings {
        let enableForceUnlock: Bool    // true
        let autoResetOnNewDay: Bool    // true
        let enableNotifications: Bool  // true
    }
    
    struct UISettings {
        let showTimer: Bool           // true
        let showProgress: Bool        // true
        let enableWidgetUpdates: Bool // true
    }
}
```

### Настройка периодов

```swift
let customConfig = ReportStatusConfig(
    timeSettings: ReportStatusConfig.TimeSettings(
        startHour: 9,
        endHour: 18,
        timeZone: .current
    ),
    // ...
)
```

## 🧪 Тестирование

### Unit тесты для ViewModels

```swift
// RegularReportsViewModelTests
class RegularReportsViewModelTests: XCTestCase {
    func testCreateRegularReport() async {
        let viewModel = RegularReportsViewModel(
            createReportUseCase: mockCreateUseCase,
            getReportsUseCase: mockGetUseCase,
            deleteReportUseCase: mockDeleteUseCase
        )
        
        await viewModel.handle(.createReport(goodItems: ["Кодил"], badItems: ["Не гулял"]))
        
        XCTAssertEqual(viewModel.state.reports.count, 1)
        XCTAssertEqual(viewModel.state.reports.first?.type, .regular)
    }
}

// CustomReportsViewModelTests
class CustomReportsViewModelTests: XCTestCase {
    func testEvaluateCustomReport() async {
        let viewModel = CustomReportsViewModel(
            createReportUseCase: mockCreateUseCase,
            updateReportUseCase: mockUpdateUseCase
        )
        
        let report = DomainPost(type: .custom, goodItems: ["Пункт 1", "Пункт 2"])
        await viewModel.handle(.evaluateReport(report, results: [true, false]))
        
        XCTAssertTrue(viewModel.state.reports.first?.isEvaluated == true)
        XCTAssertEqual(viewModel.state.reports.first?.evaluationResults, [true, false])
    }
}

// ExternalReportsViewModelTests
class ExternalReportsViewModelTests: XCTestCase {
    func testReloadFromTelegram() async {
        let viewModel = ExternalReportsViewModel(
            telegramService: mockTelegramService
        )
        
        await viewModel.handle(.refreshFromTelegram)
        
        XCTAssertFalse(viewModel.state.isRefreshing)
        XCTAssertEqual(viewModel.state.reports.count, 2) // mock data
    }
}
```

### Тестовые сценарии

1. **Первый запуск приложения**
   - Ожидаемый статус: `.notStarted`
   - Кнопка: активна
   - Таймер: "До конца"

2. **Сохранение отчета**
   - Ожидаемый статус: `.inProgress`
   - Кнопка: "Редактировать отчёт"
   - Таймер: "До конца"

3. **Отправка отчета**
   - Ожидаемый статус: `.sent`
   - Кнопка: неактивна
   - Таймер: "До старта"

4. **Новый день**
   - Статус сбрасывается на `.notStarted`
   - Все данные очищаются

## 🚀 Автоотправка

### Логика автоотправки

1. **Проверка условий**
   - Время автоотправки наступило
   - Период активен или закончился
   - Есть отчеты для отправки

2. **Отправка отчетов по типам**
   - **Regular отчеты**: Отправляются как есть
   - **Custom отчеты**: Отправляются с результатами оценки
   - **External отчеты**: Не отправляются (уже из Telegram)
   - Сообщение "За сегодня не найдено ни одного отчета" (если нет отчетов)

3. **Обновление статуса**
   - После успешной отправки статус становится `.sent`
   - Отчеты помечаются как `published: true`

### Настройки автоотправки

```swift
@Published var autoSendEnabled: Bool = true
@Published var autoSendTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
```

## 🔄 Синхронизация

### Обновление UI

```swift
// При изменении статуса
if reportStatus != newStatus {
    reportStatus = newStatus
    localService.saveReportStatus(newStatus)
    timerService.updateReportStatus(newStatus)
    WidgetCenter.shared.reloadAllTimelines()
    if notificationsEnabled { scheduleNotifications() }
}
```

### Виджеты

- Статус синхронизируется с виджетами через `WidgetCenter`
- Обновление происходит при каждом изменении статуса
- Виджеты отображают текущий статус и таймер

### Уведомления

- Уведомления планируются на основе статуса
- При изменении статуса уведомления перепланируются
- Поддержка разных режимов уведомлений

## 📱 UI компоненты

### ReportsView (Обновленная структура)

```swift
struct ReportsView: View {
    @StateObject var viewModel: ReportsViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    regularReportsSection    // RegularReportsViewModel
                    customReportsSection     // CustomReportsViewModel
                    externalReportsSection   // ExternalReportsViewModel
                }
            }
        }
    }
    
    private var regularReportsSection: some View {
        // Использует RegularReportsViewModel
    }
    
    private var customReportsSection: some View {
        // Использует CustomReportsViewModel
    }
    
    private var externalReportsSection: some View {
        // Использует ExternalReportsViewModel
    }
}
```

### MainStatusBarView

Отображает:
- Текущий статус отчета
- Таймер (время до конца/старта)
- Прогресс-бар

### LargeButtonView

Кнопка с динамическим поведением:
- **Активные статусы**: `.notStarted`, `.inProgress`
- **Неактивные статусы**: `.sent`, `.notCreated`, `.notSent`, `.done`

### Заглушка "Ждите следующего дня"

Отображается в `DailyReportView` и `RegularReportFormView` для статусов:
- `.sent`
- `.notCreated`
- `.notSent`

## 🔍 Отладка

### Логирование

```swift
print("[DEBUG] updateReportStatus: forceUnlock=\(forceUnlock), reportStatus=\(reportStatus)")
print("[DEBUG] Автоотправка: статус обновлен через updateReportStatus()")
```

### Проверка состояния

```swift
// Проверка текущего статуса
print("Текущий статус: \(store.reportStatus.displayName)")

// Проверка периода
print("Период активен: \(store.isReportPeriodActive())")

// Проверка отчетов по типам
print("Regular отчеты: \(store.posts.filter { $0.type == .regular }.count)")
print("Custom отчеты: \(store.posts.filter { $0.type == .custom }.count)")
print("External отчеты: \(store.posts.filter { $0.type == .external }.count)")
```

## 📈 Расширение модели

### Добавление нового типа отчета

1. **Добавить в PostType enum**
   ```swift
   case newType = "new_type"
   ```

2. **Создать специализированный ViewModel**
   ```swift
   class NewTypeReportsViewModel: BaseViewModel<NewTypeReportsState, NewTypeReportsEvent> {
       // Логика для нового типа отчетов
   }
   ```

3. **Добавить в ReportsViewModel**
   ```swift
   private let newTypeReportsVM: NewTypeReportsViewModel
   ```

4. **Обновить UI**
   ```swift
   private var newTypeReportsSection: some View {
       // UI для нового типа отчетов
   }
   ```

### Добавление нового статуса

1. **Добавить в enum**
   ```swift
   case newStatus = "new_status"
   ```

2. **Добавить displayName**
   ```swift
   case .newStatus: return "Новый статус"
   ```

3. **Обновить логику в updateReportStatus()**
   ```swift
   // Добавить условия для нового статуса
   ```

4. **Обновить UI компоненты**
   ```swift
   // Добавить case в switch statements
   ```

### Добавление новых настроек

1. **Расширить ReportStatusConfig**
   ```swift
   struct NewSettings {
       let newOption: Bool
   }
   ```

2. **Обновить фабрику**
   ```swift
   // Добавить логику для новых настроек
   ```

## 🎨 Кастомизация

### Изменение цветов

```swift
var reportStatusColor: Color {
    switch store.reportStatus {
    case .notStarted, .notCreated, .notSent:
        return .gray
    case .inProgress, .sent, .done:
        return .black
    }
}
```

### Изменение текстов

```swift
var reportStatusText: String {
    switch store.reportStatus {
    case .notStarted: return "Заполни отчет!"
    case .inProgress: return "Отчет заполняется..."
    // ...
    }
}
```

### Изменение периодов

```swift
let customTimeSettings = ReportStatusConfig.TimeSettings(
    startHour: 6,
    endHour: 23,
    timeZone: .current
)
```

## 📚 Дополнительные ресурсы

### Файлы модели

- `LazyBones/Models/Post.swift` - основная логика статусов
- `LazyBones/Core/Services/PostTimerService.swift` - управление таймерами
- `LazyBones/Core/Services/PostTelegramService.swift` - автоотправка
- `LazyBones/Views/Components/MainStatusBarView.swift` - отображение статуса

### Новые ViewModels (в разработке)

- `LazyBones/Presentation/ViewModels/RegularReportsViewModel.swift`
- `LazyBones/Presentation/ViewModels/CustomReportsViewModel.swift`
- `LazyBones/Presentation/ViewModels/ExternalReportsViewModel.swift`
- `LazyBones/Presentation/ViewModels/ReportsViewModel.swift`

### Тесты

- `Tests/ReportStatusFlexibilityTest.swift` - тесты гибкости
- `Tests/NewDayLogicTest.swift` - тесты логики нового дня
- `Tests/ReportPeriodLogicTest.swift` - тесты периодов
- `Tests/Presentation/ViewModels/RegularReportsViewModelTests.swift`
- `Tests/Presentation/ViewModels/CustomReportsViewModelTests.swift`
- `Tests/Presentation/ViewModels/ExternalReportsViewModelTests.swift`

### Конфигурация

- `LazyBones/Core/Common/Utils/ReportStatusConfig.swift` - настройки
- `LazyBones/Core/Common/Utils/ReportStatusFactory.swift` - фабрика статусов
- `LazyBones/Core/Common/Protocols/ReportStatusUIRepresentable.swift` - UI протоколы

---

## 🤝 Вклад в разработку

При работе со статусной моделью:

1. **Всегда используйте `updateReportStatus()`** для изменения статуса
2. **Создавайте специализированные ViewModels** для каждого типа отчета
3. **Тестируйте изменения** с помощью существующих тестов
4. **Обновляйте документацию** при добавлении новых функций
5. **Следуйте принципам** единого источника истины и реактивности

---

*Документация обновлена: 3 августа 2025* 