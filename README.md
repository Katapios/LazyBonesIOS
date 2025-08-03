# 📱 LazyBones - Приложение для ежедневных отчетов

## 🎯 Обзор продукта

**LazyBones** - это iOS приложение для создания и отправки ежедневных отчетов о продуктивности. Пользователи могут вести учет своих достижений и неудач, планировать задачи и автоматически отправлять отчеты в Telegram.

## 🏗️ Архитектура приложения

### 🎯 Clean Architecture

Проект использует **Clean Architecture** с четким разделением на слои:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  Views (SwiftUI)           │  ViewModels (ObservableObject) │
│  ├─ MainView              │  ├─ ReportListViewModel        │
│  ├─ ReportsView           │  ├─ CreateReportViewModel      │
│  ├─ SettingsView          │  └─ BaseViewModel              │
│  ├─ ReportListView        │                                │
│  └─ Forms                 │  States & Events               │
│     ├─ RegularReportForm  │  ├─ ReportListState            │
│     └─ DailyPlanningForm  │  └─ ReportListEvent            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Entities                  │  Use Cases                    │
│  ├─ DomainPost            │  ├─ CreateReportUseCase        │
│  ├─ DomainVoiceNote       │  ├─ GetReportsUseCase          │
│  └─ ReportStatus          │  ├─ UpdateStatusUseCase        │
│                            │  └─ DeleteReportUseCase        │
│  Repository Protocols      │                                │
│  ├─ PostRepositoryProtocol│                                │
│  └─ TagRepositoryProtocol │                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  Repositories              │  Data Sources                 │
│  ├─ PostRepository        │  ├─ UserDefaultsPostDataSource │
│  └─ TagRepository         │  └─ LocalStorageProtocol       │
│                            │                                │
│  Mappers                   │  Models                       │
│  ├─ PostMapper            │  ├─ Post (Data Model)          │
│  └─ VoiceNoteMapper       │  └─ VoiceNote (Data Model)     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                    │
├─────────────────────────────────────────────────────────────┤
│  Services                  │  External APIs                │
│  ├─ TelegramService       │  ├─ Telegram Bot API          │
│  ├─ NotificationService   │  └─ UserDefaults               │
│  ├─ AutoSendService       │                                │
│  └─ BackgroundTaskService │  WidgetKit                     │
└─────────────────────────────────────────────────────────────┘
```

### 🔄 Dependency Flow

```
Presentation → Domain ← Data → Infrastructure
     ↑           ↑        ↑         ↑
     └───────────┴────────┴─────────┘
           Dependency Injection
```

## 📊 Статусная модель приложения

### 🔄 Жизненный цикл отчета

```
┌─────────────────┐
│   НОВЫЙ ДЕНЬ    │
│   (8:00)        │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│  NOT_STARTED    │ ◄── Отчет не создан
│                 │     Период активен (8:00-22:00)
└─────────┬───────┘
          │
          ▼ (Создание отчета)
┌─────────────────┐
│  IN_PROGRESS    │ ◄── Отчет создан, но не отправлен
│                 │     Можно редактировать
└─────────┬───────┘
          │
          ▼ (Отправка)
┌─────────────────┐
│     SENT        │ ◄── Отчет отправлен в Telegram
│                 │     Завершен
└─────────────────┘
```

### ⏰ Временные периоды

| Период | Время | Статусы | Действия |
|--------|-------|---------|----------|
| **Активный** | 8:00 - 22:00 | `notStarted`, `inProgress` | Создание, редактирование, отправка |
| **Неактивный** | 22:00 - 8:00 | `notCreated`, `notSent`, `sent` | Только просмотр |

## 📝 Типы отчетов

### 1. 🗓️ Обычный отчет (Regular)
- **Назначение**: Ежедневный отчет о достижениях и неудачах
- **Структура**: 
  - ✅ Хорошие дела (goodItems)
  - ❌ Плохие дела (badItems)
  - 🎤 Голосовые заметки
- **Создание**: `RegularReportFormView`
- **Автоотправка**: Да

### 2. 📋 Кастомный отчет (Custom)
- **Назначение**: Планирование и оценка выполнения задач
- **Структура**:
  - 📝 План на день
  - 🏷️ Теги (хорошие/плохие)
  - ⭐ Оценка выполнения
- **Создание**: `DailyPlanningFormView`
- **Автоотправка**: Да

### 3. 📨 Внешний отчет (External)
- **Назначение**: Отчеты, полученные из Telegram
- **Источник**: Telegram Bot API
- **Обработка**: Автоматическая конвертация в Post

## 🔄 Основные пользовательские сценарии

### 1. 📱 Создание обычного отчета (Clean Architecture)
```
User → ReportListView → ReportListViewModel.handle(.createReport)
     ↓
CreateReportUseCase.execute(input: CreateReportInput)
     ↓
PostRepository.save(domainPost)
     ↓
PostMapper.toDataModel() → UserDefaultsPostDataSource.save()
     ↓
Update UI State → ReportListState.reports
```

### 2. 📋 Планирование дня
```
User → DailyPlanningFormView → CreateReportViewModel
     ↓
CreateReportUseCase.execute(input: CreateReportInput)
     ↓
PostRepository.save(domainPost)
     ↓
Status: notStarted → inProgress
```

### 3. 🤖 Автоотправка отчетов
```
BackgroundTaskService → AutoSendService → TelegramService
     ↓
GetReportsUseCase.execute(input: GetReportsInput)
     ↓
PostRepository.fetch(for: today)
     ↓
Format message → Send to Telegram → Status: sent
```

### 4. 📨 Получение отчетов из Telegram
```
TelegramService → TelegramIntegrationService
     ↓
CreateReportUseCase.execute(input: CreateReportInput)
     ↓
PostRepository.save(domainPost)
```

## 🎛️ Настройки и конфигурация

### Telegram интеграция
- **Bot Token**: Токен бота для отправки сообщений
- **Chat ID**: ID чата для получения сообщений
- **Автоотправка**: Время автоматической отправки (по умолчанию 22:00)

### Уведомления
- **Режим**: Почасовая или 2 раза в день
- **Период**: 8:00 - 22:00
- **Типы**: Напоминания о создании отчетов

### Теги
- **Хорошие теги**: ✅ Достижения и полезные дела
- **Плохие теги**: ❌ Неудачи и вредные привычки
- **Управление**: Создание, редактирование, удаление

## 📊 Статусы и их влияние на UI

| Статус | Кнопка | Таймер | Доступность форм |
|--------|--------|--------|------------------|
| `notStarted` | "Создать отчет" ✅ | "До конца" | Полная |
| `inProgress` | "Редактировать" ✅ | "До конца" | Полная |
| `sent` | "Создать отчет" ❌ | "До старта" | Заблокирована |
| `notCreated` | "Создать отчет" ❌ | "До старта" | Заблокирована |
| `notSent` | "Создать отчет" ❌ | "До старта" | Заблокирована |

## 🔧 Технические особенности

### Dependency Injection
```swift
// Контейнер зависимостей
DependencyContainer.shared.register(UserDefaultsManager.self)
DependencyContainer.shared.register(TelegramService.self)
DependencyContainer.shared.register(AutoSendService.self)

// Регистрация Use Cases
DependencyContainer.shared.register(CreateReportUseCase.self)
DependencyContainer.shared.register(GetReportsUseCase.self)
DependencyContainer.shared.register(UpdateStatusUseCase.self)
```

### App Groups
- **Назначение**: Обмен данными между приложением и виджетами
- **Хранение**: Posts, Tags, Settings, Status

### Background Tasks
- **BGAppRefreshTask**: Автоотправка отчетов
- **Регистрация**: В Info.plist и AppDelegate

### WidgetKit
- **Отображение**: Текущий статус и таймер
- **Обновление**: При изменении reportStatus

## 🧪 Тестирование

### Структура тестов
```
Tests/
├── Domain/
│   └── UseCases/
│       ├── CreateReportUseCaseTests.swift
│       ├── GetReportsUseCaseTests.swift
│       └── UpdateStatusUseCaseTests.swift
├── Data/
│   ├── Mappers/
│   │   └── PostMapperTests.swift
│   └── Repositories/
│       └── PostRepositoryTests.swift
├── Presentation/
│   └── ViewModels/
│       └── ReportListViewModelTests.swift
└── ArchitectureTests/
    ├── ServiceTests.swift
    ├── VoiceRecorderTests.swift
    └── ReportStatusFlexibilityTest.swift
```

### Покрытие тестами
- **Domain Layer**: 100% покрытие Use Cases
- **Data Layer**: 100% покрытие Repositories и Mappers
- **Presentation Layer**: 100% покрытие ViewModels
- **Integration Tests**: Тестирование взаимодействия слоев

## 📈 Метрики и аналитика

### Ключевые показатели
- Количество созданных отчетов
- Процент отправленных отчетов
- Активность пользователей по времени
- Популярность тегов

### Отслеживание событий
- Создание отчета
- Отправка отчета
- Использование голосовых заметок
- Взаимодействие с тегами

## 🚀 Возможности для развития

### Краткосрочные
- [x] ✅ Clean Architecture implementation
- [x] ✅ Domain Layer with Use Cases
- [x] ✅ Data Layer with Repositories
- [x] ✅ Presentation Layer with ViewModels
- [ ] 🔄 Integration of existing Views with new architecture
- [ ] 🔄 Dependency Injection container setup
- [ ] Экспорт отчетов в PDF
- [ ] Статистика и графики

### Долгосрочные
- [ ] Веб-версия приложения
- [ ] Командная аналитика
- [ ] Интеграция с календарем
- [ ] AI-анализ отчетов

## 📋 Статус миграции на Clean Architecture

### ✅ Завершено
- [x] **Domain Layer**: Entities, Use Cases, Repository Protocols
- [x] **Data Layer**: Repositories, Data Sources, Mappers
- [x] **Presentation Layer**: ViewModels, States, Events
- [x] **Testing**: Unit tests для всех слоев
- [x] **Code Quality**: Исправлены все предупреждения компилятора

### 🔄 В процессе
- [ ] **Integration**: Подключение существующих Views к новой архитектуре
- [ ] **Dependency Injection**: Настройка контейнера зависимостей
- [ ] **Migration**: Постепенная миграция существующих ViewModels

### 📋 Планируется
- [ ] **Performance**: Оптимизация производительности
- [ ] **Documentation**: Дополнительная документация API
- [ ] **Monitoring**: Добавление метрик и мониторинга

## 📞 Контакты

- **Разработчик**: Денис Рюмин
- **Версия**: 1.0.0
- **Платформа**: iOS 17.0+
- **Архитектура**: Clean Architecture

---

*Документация обновлена: 3 августа 2025*
*Статус: Clean Architecture - 70% завершено*
