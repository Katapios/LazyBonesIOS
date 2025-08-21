# 🧼 Миграция на Clean Architecture — актуальный статус

Этот документ фиксирует план и текущий прогресс переноса LazyBones на Clean Architecture, фактические точки интеграции и следующий шаги. Обновляется по мере изменений кода и тестов.

## 🎯 Цели миграции

- Чистое разделение слоёв: Domain, Data, Core(Infrastructure), Presentation
- Тестируемость: изоляция состояний, детерминированные юниты и интеграции
- Предсказуемые побочные эффекты: уведомления, таймеры, Telegram
- Упрощение UI-слоя: ViewModel ↔ UseCases, без доступа к хранилищам напрямую

## 🧱 Слои и ключевые компоненты

- Domain: Entities, UseCases, Repository Protocols (готово)
- Data: Repositories, DataSources, Mappers (готово)
- Core(Infrastructure): сервисы и системные адаптеры
  - `LocalReportService`, `NotificationManagerService`, `ReportStatusManager`, `Telegram*Services`, `PostTimerService`, `AutoSendService`, `LegacyUISyncAdapter`
- Presentation: ViewModels (новые), Views (частично)

## 📌 Текущий статус (обновлено)

- __Новые ViewModel'и (Clean)__:
  - `LazyBones/Presentation/ViewModels/MainViewModelNew.swift`
  - `LazyBones/Presentation/ViewModels/ReportsViewModelNew.swift`
  - `LazyBones/Presentation/ViewModels/SettingsViewModelNew.swift`
- __Новые/чистые View__:
  - Главная: `LazyBones/Views/MainViewNew.swift` (готова, но пока не подключена в `ContentView`)
  - Отчёты: `LazyBones/Views/ReportsViewClean.swift` (подключена в таб «Отчёты»)
  - Компоненты: `ReportCardViewNew.swift`, `CustomReportEvaluationViewNew.swift`
- __Что уже на Clean в рантайме__:
  - Таб «Отчёты»: `ReportsViewClean` + `ReportsViewModelNew`
  - Таб «Настройки»: `SettingsView` использует `SettingsViewModelNew`
  - Таб «Теги»: `TagManagerViewClean` + `TagManagerViewModelNew`
- __Что ещё на legacy в рантайме__:
  - Таб «Главная»: `ContentView` всё ещё показывает `MainView` (старый, через `PostStore`), хотя есть `MainViewNew`
  - Таб «План» (`DailyPlanningFormView`) — использует legacy состояние/сервисы
  - Формы отчётов: `RegularReportFormView`, `PostFormView`, `DailyReportView` — завязаны на `PostStore`
- __Инфраструктура/DI__:
  - DI контейнер (`DependencyContainer`) регистрирует use‑cases, репозитории, сервисы и фабрики `*ViewModelNew`
- __Legacy артефакты__ (подлежат удалению после миграции представлений):
  - `PostStore`, `PostStoreAdapter`, `LegacyUISyncAdapter`, старые `*ViewModel`
- __Сервисная часть актуализирована__:
  - `ReportStatusManager` с `forceUnlock`, синхронизацией статуса и нотификацией `reportStatusDidChange`
  - `LocalReportService` — in‑memory стора для XCTest и очистка в `PostStore.init()`

## ✅ Завершено

- Исправление логики сохранения/публикации (upsert) в `PostFormViewModel` 
- Изоляция тестовых данных (in-memory в `LocalReportService`, очистка в `PostStore` при XCTest)
- Актуализация статусов и взаимодействия с таймером/уведомлениями в `ReportStatusManager`
- Обновлена документация по тестированию и статусной модели
- Удалены legacy-вью настроек: `TelegramSettingsView`, `NotificationSettingsView`; секции инлайн в `SettingsView`, навигация упрощена в `SettingsCoordinator`
 - Расширены юнит‑тесты `SettingsViewModelNew`: сценарии `resetReportUnlock` и негативный `iCloud export` (ошибка форматирования)
- Реализованы `TagManagerViewModelNew` и `TagManagerViewClean`; подключены в таб «Теги»

## 🚧 В процессе / Предстоит

1) Подключение Clean View в `ContentView`
- Заменить `MainView(store:)` на `MainViewNew()`
- Заменить `ReportsView` (если где-то остался) на `ReportsViewClean()` — уже подключён в табе «Отчёты»
- Заменить `TagManagerView(store:)` на новый `TagManagerViewClean()` — уже подключён в табе «Теги»
- Заменить `DailyPlanningFormView()` на новый `PlanningViewClean()` (после реализации)
- Удалить передачу `.environmentObject(store)` из `ContentView`

2) Новые ViewModel/Views для Planning
- Реализовать `PlanningViewModelNew` и `PlanningViewClean` (вкладка «План»), использовать use‑cases для сохранения/публикации

3) Миграция форм отчётов с PostStore на UseCases
- `RegularReportFormViewClean` (create/update через `CreateReportUseCase`/`UpdateReportUseCase`, теги через `TagRepository`)
- `PostFormViewClean`
- `DailyReportViewClean`
- Интеграция с Telegram/уведомлениями через соответствующие сервисы из DI

4) Очистка `PostStore` и адаптеров
- Убрать `PostStore` из `ContentView` и всех зависимостей после перевода экранов
- Удалить `PostStoreAdapter`, сократить/удалить `LegacyUISyncAdapter`

5) Координация и навигация
- Обновить `AppCoordinator` для навигации к «чистым» формам/экранчикам
- Обновить обновление виджетов/сайд‑эффектов на событиях новых VM

6) Тесты Presentation слоя
- Добавить недостающие тесты: `MainViewModelNew`, `ReportsViewModelNew` (покрыть углы), `TagManagerViewModelNew`, `PlanningViewModelNew`, формы
- Статус: для `SettingsViewModelNew` — частично выполнено (добавлены `resetReportUnlock`, негативные кейсы iCloud экспорта)
- Сценарии: `forceUnlock`, автоотправка, ошибки Telegram, iCloud экспорт

## 🔄 План миграции (чек‑лист)

- [ ] Подключить `MainViewNew` в `ContentView` (заменить `MainView(store:)`)
- [x] Подключить `ReportsViewClean` в таб «Отчёты»
- [x] Удалить legacy‑вью настроек (`TelegramSettingsView`, `NotificationSettingsView`); секции инлайн в `SettingsView`
- [x] Реализовать `TagManagerViewModelNew` + `TagManagerViewClean`; подключить в таб «Теги»
- [ ] Реализовать `PlanningViewModelNew` + `PlanningViewClean`; подключить в таб «План»
- [ ] Перенести формы: `RegularReportFormViewClean`, `PostFormViewClean`, `DailyReportViewClean` на use‑cases/репозитории
- [ ] Убрать `.environmentObject(PostStore.shared)` из `ContentView` и связанных
- [ ] Удалить `PostStore`, `PostStoreAdapter`, `LegacyUISyncAdapter`
- [ ] Обновить `AppCoordinator` под навигацию к новым экранам и паблиш‑сайд‑эффектам
- [ ] Дописать/обновить тесты новых VM и форм (краевые сценарии)
- [ ] Прогнать интеграционные тесты и регресс после удаления legacy

## 🔗 Точки интеграции и события

- Статусы: `ReportStatusManager.updateStatus()` и `Notification.Name.reportStatusDidChange`
- Таймер: `PostTimerService` шлёт `reportPeriodActivityChanged` каждый тик
- Уведомления: `NotificationManagerService.scheduleNotificationsIfNeeded()`
- Telegram: ручная и автоотправка (см. `TELEGRAM_SETUP.md`)

## 🧪 Тестирование и стабильность

- Изоляция состояний тестов: in-memory стора (`LocalReportService.testPostsStorage`), сброс постов в `PostStore.init()` при XCTest
- Сбои симулятора: см. «Стабильность симулятора» в `TESTING_GUIDE.md`

## 📚 См. также

- `README.md` — функциональность и использование
- `STATUS_MODEL_README.md` — статусы и UI‑правила
- `TESTING_GUIDE.md` — запуск и стабилизация тестов
- `TELEGRAM_SETUP.md` — настройка Telegram
