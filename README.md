# LazyBones

Приложение для ведения ежедневных отчетов с интеграцией Telegram и поддержкой голосовых заметок.

## Архитектура

Проект использует **Clean Architecture** с разделением на слои и модули:

### Основные принципы

- **Разделение ответственности (Separation of Concerns)**: Каждый компонент имеет только одну причину для изменения
- **Модульность**: Разделение приложения на логические, независимые модули
- **Тестируемость**: Возможность легко тестировать каждую часть приложения в изоляции
- **Масштабируемость**: Способность легко добавлять новые функции без значительного рефакторинга
- **Однонаправленный поток данных**: Упрощает отладку и понимание поведения приложения
- **Dependency Injection**: Управление зависимостями для улучшения тестируемости и гибкости

### Структура проекта

```
LazyBones/
├── Application/                    # Точка входа и координация
│   ├── AppCoordinator.swift       # Главный координатор приложения
│   └── LazyBonesApp.swift         # Точка входа в приложение
│
├── Core/                          # Общая инфраструктура
│   ├── Common/                    # Общие компоненты
│   │   ├── Extensions/            # Расширения для стандартных типов
│   │   ├── Protocols/             # Общие протоколы
│   │   └── Utils/                 # Утилиты (DateUtils, Logger)
│   ├── Networking/                # Слой работы с сетью
│   │   ├── APIClient.swift        # Базовый API клиент
│   │   └── Models/                # Модели для сетевых запросов
│   ├── Persistence/               # Слой работы с данными
│   │   └── UserDefaultsManager.swift
│   └── Services/                  # Общие сервисы
│       ├── TelegramService.swift  # Сервис для работы с Telegram
│       ├── NotificationService.swift # Сервис уведомлений
│       └── BackgroundTaskService.swift # Сервис фоновых задач
│
├── Features/                      # Модули функциональности
│   ├── Reports/                   # Модуль отчетов
│   │   ├── Models/                # Модели отчетов
│   │   ├── Repositories/          # Репозитории
│   │   ├── DataSources/           # Источники данных
│   │   ├── UseCases/              # Бизнес-логика
│   │   ├── ReportsViewModel.swift # ViewModel
│   │   └── ReportsCoordinator.swift # Координатор
│   ├── VoiceRecorder/             # Модуль записи голоса
│   ├── Settings/                  # Модуль настроек
│   ├── Planning/                  # Модуль планирования
│   └── Main/                      # Главный модуль
│
├── Views/                         # UI компоненты
│   ├── Components/                # Переиспользуемые компоненты
│   ├── Forms/                     # Формы
│   └── ContentView.swift          # Главный экран
│
├── Resources/                     # Ресурсы
│   ├── Assets.xcassets/           # Изображения и цвета
│   └── Fonts/                     # Шрифты
│
└── Support Files/                 # Вспомогательные файлы
    ├── Info.plist
    └── LazyBones.entitlements
```

## Основные компоненты

### Модели данных

- **Report**: Модель отчёта пользователя
- **VoiceNote**: Модель голосовой заметки
- **ReportType**: Типы отчетов (обычный, кастомный, внешний)
- **ReportStatus**: Статусы отчетов

### Сервисы

- **TelegramService**: Интеграция с Telegram API
- **NotificationService**: Управление уведомлениями
- **BackgroundTaskService**: Фоновые задачи
- **UserDefaultsManager**: Управление настройками

### Use Cases

- **GetReportsUseCase**: Получение отчетов
- **SearchReportsUseCase**: Поиск отчетов
- **GetReportStatisticsUseCase**: Статистика отчетов

### Репозитории

- **ReportRepository**: Работа с отчетами
- **ReportLocalDataSource**: Локальное хранение
- **ReportRemoteDataSource**: Удаленное хранение

## Принципы разработки

### Чистая архитектура

1. **Domain Layer**: Бизнес-логика и модели
2. **Data Layer**: Репозитории и источники данных
3. **Presentation Layer**: UI и ViewModels
4. **Infrastructure Layer**: Внешние сервисы и API

### Dependency Injection

Все зависимости инжектируются через конструкторы, что обеспечивает:
- Легкое тестирование
- Гибкость в замене реализаций
- Слабое связывание компонентов

### Однонаправленный поток данных

```
Action → UseCase → Repository → DataSource → Response
   ↑                                                    ↓
ViewModel ← Presentation ← UI ← User Interaction
```

## Настройка проекта

### Требования

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

### Установка

1. Клонируйте репозиторий
2. Откройте `LazyBones.xcodeproj` в Xcode
3. Настройте Bundle Identifier и Team
4. Добавьте необходимые capabilities:
   - Background Modes (Background fetch, Background processing)
   - App Groups
5. Соберите и запустите проект

### Настройка Telegram

1. Создайте бота через @BotFather
2. Получите токен бота
3. Добавьте токен в настройки приложения
4. Настройте chat ID для отправки сообщений

### Настройка фоновых задач

1. Включите Background Modes в capabilities
2. Добавьте `BGTaskSchedulerPermittedIdentifiers` в Info.plist
3. Укажите идентификатор: `com.katapios.LazyBones.sendReport`

## Тестирование

### Unit Tests

- Тесты для Use Cases
- Тесты для Repositories
- Тесты для Services
- Тесты для ViewModels

### UI Tests

- Тесты пользовательских сценариев
- Тесты навигации
- Тесты форм

## Логирование

Проект использует структурированное логирование через `Logger`:

```swift
Logger.info("Message", log: Logger.ui)
Logger.debug("Debug info", log: Logger.data)
Logger.error("Error occurred", log: Logger.error)
```

## Лицензия

MIT License
