# 📋 Чек-лист миграции на Clean Architecture

## 📊 Общий прогресс: 65% завершено

**Дата обновления**: 5 августа 2025  
**Статус**: Частичная миграция на Clean Architecture

## ✅ Завершенные этапы

### Фаза 1: Подготовка и планирование ✅
- [x] Инвентаризация всех компонентов
- [x] Выявление зависимостей между модулями
- [x] Создание карты миграции
- [x] Создание новой структуры папок
- [x] Настройка базовых протоколов

### Фаза 2: Domain Layer ✅
- [x] Создать Domain Entities
  - [x] `DomainPost`
  - [x] `DomainVoiceNote`
  - [x] `ReportStatus`
- [x] Реализовать Use Cases
  - [x] `CreateReportUseCase`
  - [x] `GetReportsUseCase`
  - [x] `UpdateReportUseCase`
  - [x] `DeleteReportUseCase`
  - [x] `UpdateStatusUseCase`
  - [x] `ExportReportsUseCase`
  - [x] `ImportICloudReportsUseCase`
- [x] Создать Repository Protocols
  - [x] `PostRepositoryProtocol`
  - [x] `TagRepositoryProtocol`
  - [x] `ReportFormatterProtocol`

### Фаза 3: Data Layer ✅
- [x] Создать Data Models
  - [x] `Post` (Data Model)
  - [x] `VoiceNote` (Data Model)
- [x] Реализовать Data Sources
  - [x] `UserDefaultsPostDataSource`
  - [x] `ICloudFileManager`
- [x] Создать Repository реализации
  - [x] `PostRepository`
  - [x] `TagRepository`
  - [x] `SettingsRepository`
  - [x] `ICloudReportRepository`
- [x] Создать Mappers
  - [x] `PostMapper`
  - [x] `VoiceNoteMapper`
  - [x] `ICloudReportMapper`

### Фаза 4: Infrastructure Layer ✅
- [x] Мигрировать сервисы
  - [x] `TelegramService`
  - [x] `NotificationService`
  - [x] `AutoSendService`
  - [x] `BackgroundTaskService`
  - [x] `ICloudService`
  - [x] `ReportStatusManager`
- [x] Обновить DI контейнер
  - [x] `DependencyContainer`
  - [x] Регистрация всех сервисов
  - [x] Регистрация Use Cases
  - [x] Регистрация Repositories
- [x] Настроить зависимости
  - [x] `AppCoordinator`
  - [x] `MainCoordinator`
  - [x] `ReportsCoordinator`
  - [x] `SettingsCoordinator`
  - [x] `TagsCoordinator`
  - [x] `PlanningCoordinator`

### Фаза 5: Presentation Layer (частично) 🔄
- [x] Создать базовые классы
  - [x] `BaseViewModel`
  - [x] `ViewModelProtocol`
  - [x] `LoadableViewModel`
- [x] Создать States и Events
  - [x] `RegularReportsState` и `RegularReportsEvent`
  - [x] `CustomReportsState` и `CustomReportsEvent`
  - [x] `ExternalReportsState` и `ExternalReportsEvent`
  - [x] `ReportListState` и `ReportListEvent`
- [x] Создать ViewModels с новой архитектурой
  - [x] `RegularReportsViewModel` ✅
  - [x] `CustomReportsViewModel` ✅
  - [x] `ExternalReportsViewModel` ✅
  - [x] `ReportListViewModel` ✅
- [x] Создать Views с новой архитектурой
  - [x] `ExternalReportsView` ✅ (единственный!)
- [x] Создать ViewModels-адаптеры (старая архитектура)
  - [x] `MainViewModel` 🔄 (оборачивает PostStore)
  - [x] `ReportsViewModel` 🔄 (оборачивает PostStore)
  - [x] `SettingsViewModel` 🔄 (оборачивает PostStore)
  - [x] `TagManagerViewModel` 🔄 (оборачивает PostStore)

### Фаза 6: Тестирование ✅
- [x] Unit тесты для Domain Layer
  - [x] `CreateReportUseCaseTests`
  - [x] `GetReportsUseCaseTests`
  - [x] `UpdateReportUseCaseTests`
  - [x] `DeleteReportUseCaseTests`
  - [x] `UpdateStatusUseCaseTests`
- [x] Unit тесты для Data Layer
  - [x] `PostRepositoryTests`
  - [x] `PostMapperTests`
  - [x] `TagRepositoryTests`
- [x] Unit тесты для Presentation Layer
  - [x] `RegularReportsViewModelTests`
  - [x] `CustomReportsViewModelTests`
  - [x] `ExternalReportsViewModelTests`
  - [x] `ReportListViewModelTests`
  - [x] `MainViewModelTests`
  - [x] `ReportsViewModelTests`
  - [x] `SettingsViewModelTests`
  - [x] `TagManagerViewModelTests`
  - [x] `PostFormViewModelTests`
- [x] Integration тесты
  - [x] `ExternalReportsIntegrationTests`
  - [x] `ICloudIntegrationTests`
  - [x] `AutoSendIntegrationTests`
- [x] Architecture тесты
  - [x] `AppCoordinatorTests`
  - [x] `CoordinatorTests`
  - [x] `ServiceTests`
  - [x] `ICloudServiceTests`

## 🔄 Текущие этапы (35% осталось)

### Фаза 7: Создание настоящих ViewModels (КРИТИЧЕСКИЙ ПРИОРИТЕТ) 🔄
- [ ] Создать `MainViewModel` с новой архитектурой
  - [ ] Использовать `BaseViewModel<MainState, MainEvent>`
  - [ ] Инжектировать `UpdateStatusUseCaseProtocol`
  - [ ] Инжектировать `GetReportsUseCaseProtocol`
  - [ ] Реализовать `handle(_ event: MainEvent) async`
  - [ ] Добавить `MainState` и `MainEvent`
  - [ ] Написать unit тесты
- [ ] Создать `ReportsViewModel` с новой архитектурой
  - [ ] Использовать `BaseViewModel<ReportsState, ReportsEvent>`
  - [ ] Инжектировать `RegularReportsViewModel`
  - [ ] Инжектировать `CustomReportsViewModel`
  - [ ] Инжектировать `ExternalReportsViewModel`
  - [ ] Реализовать `handle(_ event: ReportsEvent) async`
  - [ ] Добавить `ReportsState` и `ReportsEvent`
  - [ ] Написать unit тесты
- [ ] Создать `SettingsViewModel` с новой архитектурой
  - [ ] Использовать `BaseViewModel<SettingsState, SettingsEvent>`
  - [ ] Инжектировать `UserDefaultsManagerProtocol`
  - [ ] Инжектировать `NotificationManagerServiceType`
  - [ ] Реализовать `handle(_ event: SettingsEvent) async`
  - [ ] Добавить `SettingsState` и `SettingsEvent`
  - [ ] Написать unit тесты
- [ ] Создать `TagManagerViewModel` с новой архитектурой
  - [ ] Использовать `BaseViewModel<TagManagerState, TagManagerEvent>`
  - [ ] Инжектировать `TagRepositoryProtocol`
  - [ ] Реализовать `handle(_ event: TagManagerEvent) async`
  - [ ] Добавить `TagManagerState` и `TagManagerEvent`
  - [ ] Написать unit тесты

### Фаза 8: Миграция Views (КРИТИЧЕСКИЙ ПРИОРИТЕТ) 🔄
- [ ] Мигрировать `MainView`
  - [ ] Удалить параметр `store: PostStore`
  - [ ] Использовать новый `MainViewModel`
  - [ ] Инжектировать зависимости через DI контейнер
  - [ ] Обновить UI для работы с новым ViewModel
  - [ ] Написать UI тесты
- [ ] Мигрировать `ReportsView`
  - [ ] Удалить параметр `store: PostStore`
  - [ ] Использовать новый `ReportsViewModel`
  - [ ] Инжектировать зависимости через DI контейнер
  - [ ] Обновить UI для работы с новым ViewModel
  - [ ] Написать UI тесты
- [ ] Мигрировать `SettingsView`
  - [ ] Удалить параметр `store: PostStore`
  - [ ] Использовать новый `SettingsViewModel`
  - [ ] Инжектировать зависимости через DI контейнер
  - [ ] Обновить UI для работы с новым ViewModel
  - [ ] Написать UI тесты
- [ ] Мигрировать `TagManagerView`
  - [ ] Удалить параметр `store: PostStore`
  - [ ] Использовать новый `TagManagerViewModel`
  - [ ] Инжектировать зависимости через DI контейнер
  - [ ] Обновить UI для работы с новым ViewModel
  - [ ] Написать UI тесты

### Фаза 9: Обновление ContentView (ВЫСОКИЙ ПРИОРИТЕТ) 🔄
- [ ] Удалить `@StateObject var store = PostStore()`
- [ ] Удалить передачу `store` в Views
- [ ] Удалить `.environmentObject(store)`
- [ ] Обновить инициализацию Views
- [ ] Протестировать навигацию
- [ ] Написать integration тесты

### Фаза 10: Рефакторинг PostStore (ВЫСОКИЙ ПРИОРИТЕТ) 🔄
- [ ] Удалить `PostStore.swift`
- [ ] Удалить `Post.swift` (оставить только `DomainPost`)
- [ ] Удалить ViewModels-адаптеры
  - [ ] Удалить старый `MainViewModel`
  - [ ] Удалить старый `ReportsViewModel`
  - [ ] Удалить старый `SettingsViewModel`
  - [ ] Удалить старый `TagManagerViewModel`
- [ ] Обновить все импорты
- [ ] Удалить зависимости от PostStore в сервисах
- [ ] Обновить тесты

### Фаза 11: Обновление DI контейнера 🔄
- [ ] Добавить регистрацию новых ViewModels
  - [ ] `MainViewModel`
  - [ ] `ReportsViewModel`
  - [ ] `SettingsViewModel`
  - [ ] `TagManagerViewModel`
- [ ] Удалить регистрацию старых ViewModels
- [ ] Удалить регистрацию PostStore
- [ ] Обновить зависимости
- [ ] Протестировать DI контейнер

### Фаза 12: Финальная очистка 🔄
- [ ] Проверить весь проект на наличие оставшегося "старого" кода
- [ ] Удалить неиспользуемые импорты
- [ ] Удалить неиспользуемые файлы
- [ ] Обновить документацию
- [ ] Провести code review
- [ ] Запустить полный набор тестов

## 📊 Детальная статистика

### По слоям архитектуры
| Слой | Статус | Прогресс | Компоненты |
|------|--------|----------|------------|
| **Domain Layer** | ✅ | 100% | Entities, Use Cases, Repository Protocols |
| **Data Layer** | ✅ | 100% | Repositories, Data Sources, Mappers |
| **Presentation Layer** | 🔄 | 30% | ViewModels готовы частично, Views в миграции |
| **Infrastructure Layer** | ✅ | 100% | Services, DI Container, Coordinators |

### По типам компонентов
| Тип | Статус | Прогресс | Описание |
|-----|--------|----------|----------|
| **Entities** | ✅ | 100% | DomainPost, DomainVoiceNote, ReportStatus |
| **Use Cases** | ✅ | 100% | Все основные сценарии использования |
| **Repositories** | ✅ | 100% | PostRepository, TagRepository, etc. |
| **ViewModels (новая архитектура)** | ✅ | 100% | RegularReports, CustomReports, ExternalReports |
| **ViewModels (старая архитектура)** | 🔄 | 0% | MainViewModel, ReportsViewModel, etc. |
| **Views (новая архитектура)** | ✅ | 25% | Только ExternalReportsView |
| **Views (старая архитектура)** | 🔄 | 0% | MainView, ReportsView, SettingsView |
| **Services** | ✅ | 100% | Все сервисы мигрированы |
| **Tests** | ✅ | 90% | Unit и Integration тесты |

## 🚨 Критические проблемы

### 1. **Двойная архитектура**
- [ ] Новая архитектура: ExternalReportsView ✅
- [ ] Старая архитектура: Все остальные Views ❌

### 2. **PostStore как глобальное состояние**
- [ ] ContentView создает PostStore глобально ❌
- [ ] PostStore передается во все Views ❌
- [ ] PostStore используется через Environment ❌

### 3. **ViewModel-адаптеры**
- [ ] MainViewModel оборачивает PostStore ❌
- [ ] ReportsViewModel оборачивает PostStore ❌
- [ ] SettingsViewModel оборачивает PostStore ❌
- [ ] TagManagerViewModel оборачивает PostStore ❌

## 🎯 Следующие шаги

### Неделя 1: Создание ViewModels
- [ ] Создать MainViewModel с новой архитектурой
- [ ] Создать ReportsViewModel с новой архитектурой
- [ ] Создать SettingsViewModel с новой архитектурой
- [ ] Создать TagManagerViewModel с новой архитектурой

### Неделя 2: Миграция Views
- [ ] Мигрировать MainView
- [ ] Мигрировать ReportsView
- [ ] Мигрировать SettingsView
- [ ] Мигрировать TagManagerView

### Неделя 3: Очистка
- [ ] Обновить ContentView
- [ ] Удалить PostStore
- [ ] Обновить DI контейнер
- [ ] Финальная очистка

## 📈 Метрики успеха

### Технические метрики
- [x] Покрытие тестами > 80% ✅
- [x] Время сборки < 2 минут ✅
- [x] Размер приложения не увеличился > 10% ✅
- [ ] Архитектурная готовность 100% 🔄

### Качественные метрики
- [x] Количество багов уменьшилось ✅
- [ ] Время разработки новых функций сократилось 🔄
- [x] Код стал более читаемым ✅
- [ ] Полная Clean Architecture ✅

## 🏁 Заключение

**Текущий прогресс: 65% завершено**

**Критические задачи для завершения:**
1. Создание настоящих ViewModels для основных Views
2. Миграция Views на новую архитектуру
3. Удаление PostStore и связанного кода
4. Обновление ContentView

**Время до завершения: 3-4 недели**

---

*Чек-лист создан: 3 августа 2025*  
*Последнее обновление: 5 августа 2025*  
*Статус: 65% завершено* 