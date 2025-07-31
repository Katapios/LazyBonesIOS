# 📊 Статусная модель LazyBones

## Обзор

Статусная модель LazyBones - это централизованная система управления состоянием отчетов, которая определяет поведение UI, таймеров и автоматических процессов в приложении.

## 🎯 Основные принципы

### Единый источник истины
- Все статусы определены в `ReportStatus` enum
- Централизованное обновление через `PostStore.updateReportStatus()`
- Синхронизация между сервисами через callbacks

### Реактивность
- Использование `@Published` для автоматического обновления UI
- Синхронизация с виджетами и уведомлениями
- Обновление таймеров в реальном времени

### Модульность
- Четкое разделение ответственности между компонентами
- Использование протоколов для тестируемости
- Dependency Injection для гибкости

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

#### 1. PostStore
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

#### 2. PostTimerService
```swift
class PostTimerService {
    func updateReportStatus(_ status: ReportStatus) {
        // Обновление таймера на основе статуса
    }
}
```

#### 3. UI компоненты
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

### Схема взаимодействия

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   UI Views  │◄──►│  PostStore  │◄──►│   Services  │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Widgets   │    │UserDefaults │    │ Telegram    │
└─────────────┘    └─────────────┘    └─────────────┘
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

### Unit тесты

```swift
class ReportStatusFlexibilityTest: XCTestCase {
    func testStatusCreation() {
        let status = factory.createStatus(
            hasRegularReport: false,
            isReportPublished: false,
            isPeriodActive: true
        )
        XCTAssertEqual(status, .notStarted)
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

2. **Отправка отчетов**
   - Regular отчеты (если есть)
   - Custom отчеты (если есть)
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

// Проверка отчетов
print("Есть regular отчет: \(store.posts.contains { $0.type == .regular })")
```

## 📈 Расширение модели

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

### Тесты

- `Tests/ReportStatusFlexibilityTest.swift` - тесты гибкости
- `Tests/NewDayLogicTest.swift` - тесты логики нового дня
- `Tests/ReportPeriodLogicTest.swift` - тесты периодов

### Конфигурация

- `LazyBones/Core/Common/Utils/ReportStatusConfig.swift` - настройки
- `LazyBones/Core/Common/Utils/ReportStatusFactory.swift` - фабрика статусов
- `LazyBones/Core/Common/Protocols/ReportStatusUIRepresentable.swift` - UI протоколы

---

## 🤝 Вклад в разработку

При работе со статусной моделью:

1. **Всегда используйте `updateReportStatus()`** для изменения статуса
2. **Тестируйте изменения** с помощью существующих тестов
3. **Обновляйте документацию** при добавлении новых функций
4. **Следуйте принципам** единого источника истины и реактивности

---

*Документация обновлена: 31 июля 2025* 