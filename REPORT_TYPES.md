# Типы отчетов в LazyBonesIOS

Документ описывает ключевые отличия и поведение типов отчетов: regular (локальные), custom (кастомные/план), external (внешние из Telegram), iCloud (импорт/экспорт).

## Краткие выводы

- **Custom**:
  - Поддерживает оценку (`isEvaluated`, `evaluationResults`).
  - Не имеет bad-пунктов и bad-тегов.
  - Теги всегда сохраняются как good.
- **Regular**:
  - Имеет раздельные good/bad пункты и соответствующие теги.
  - Сохранение тегов зависит от переключателя good/bad.
  - Именно regular привязан к статусной модели и таймерам, и подпадает под force unlock из настроек.
- **External**: отчеты, полученные из Telegram, только чтение в списке.
- **iCloud**: экспорт/импорт отчетов, не влияет на статусную модель.

Ниже — подтверждения по коду с ссылками на соответствующие файлы/символы.

---

## Regular (локальные)

- **UI и логика good/bad пунктов и тегов**
  - Экран: `LazyBones/Views/Forms/RegularReportFormView.swift`.
  - Разделение на good/bad через `selectedTab` и соответствующие списки и колесо тегов.
  - Сохранение тегов по выбранной вкладке: при промпте «Сохранить тег?» вызывается `addGoodTag` или `addBadTag` в зависимости от `selectedTab`.
  - См. также форму дневного отчета `LazyBones/Views/Forms/DailyReportView.swift` (good/bad секции, публикация и т.д.).

- **Навигация из главной кнопкой «Создать/Редактировать» ведет в форму regular**
  - Главная: `LazyBones/Views/MainViewNew.swift`, секция `PrimaryActionButtonSection` вызывает `appCoordinator.switchToTab(.planning)`.
  - Вкладка Planning содержит `DailyPlanningFormView` (`LazyBones/Views/Forms/DailyPlanningFormView.swift`), у которого первый таб — `DailyReportView()` (стр. с заголовком «Отчет за день»). Это и есть форма regular.

- **Привязка к статусной модели и таймерам**
  - Менеджер статусов: `LazyBones/Core/Services/ReportStatusManager.swift`.
    - Учет только **regular** отчетов при расчете статуса: поиск поста с `type == .regular` за сегодня (`getPosts()`, фильтр по типу и дате).
    - Обновление зависимостей статуса: `timerService.updateReportStatus(status)`, уведомления и виджеты.
    - Поддержка `forceUnlock` и его влияние на состояние редактирования регулярного отчета.
  - Главный экран: `LazyBones/Views/MainViewNew.swift` — запускает/останавливает таймер-сервис и отображает прогресс таймера и статус (state ViewModel-а берется из UseCase/TimerService).

- **Force Unlock из настроек**
  - Экран настроек: `LazyBones/Views/SettingsView.swift` — кнопка «Разблокировать отчёты» вызывает событие `.unlockReports`.
  - ViewModel настроек: `LazyBones/Presentation/ViewModels/SettingsViewModelNew.swift` → `unlockReports()` вызывает `statusManager.unlockReportCreation()`.
  - Логика разблокировки: `ReportStatusManager.unlockReportCreation()`
    - Устанавливает `forceUnlock = true` и сохраняет в Local storage.
    - Если на сегодня есть regular-отчет с `published == true`, снимает публикацию, не удаляя данные, тем самым разрешая редактирование.
    - Статус переводится в `.notStarted`, сервисы и виджеты обновляются, таймер получает `updateReportStatus`.

---

## Custom (кастомные отчеты/план)

- **Источник данных и UI (план дня)**
  - Экран: `LazyBones/Views/Forms/DailyPlanningFormView.swift` → вложенная `PlanningContentView`.
  - Ввод пунктов плана: `planItems` и колесо тегов из good-тегов (`planTags`). Отсутствуют bad-пункты.

- **Сохранение кастомного отчета**
  - `LazyBones/Presentation/ViewModels/PlanningViewModel.swift` → `savePlanAsReport()`
    - Формирует `Post` c `type: .custom`, `goodItems: planItems`, `badItems: []`.

- **Оценка**
  - `Post` содержит `isEvaluated`, `evaluationResults` (используются только для custom).
  - Публикация кастома требует оценку: `PlanningViewModel.publishCustomReportToTelegram()` проверяет `custom.isEvaluated`.
  - Экран списка отчетов: `LazyBones/Views/ReportsViewClean.swift` — на карточке custom доступна кнопка «Оценить» (`showEvaluateButton`, `onEvaluate`).

- **Теги в custom — всегда good**
  - Промпт «Сохранить тег?» сохраняет только в good: `repo.addGoodTag(...)` в `DailyPlanningFormView.swift` (`PlanningContentView.planSection`).
  - Источник тегов: `planTags` берутся из `tagProvider?.goodTags ?? store.goodTags`.

---

## External (из Telegram)

- Экран: `LazyBones/Presentation/ViewModels/ExternalReportsViewModel.swift` и `LazyBones/Views/ExternalReportsView.swift` (включается через `ReportsViewClean`).
- Отчеты подгружаются из Telegram, доступны операции обновления/очистки истории/удаления внешних записей. Не участвуют в статусной модели.

---

## iCloud

- Сервис: `LazyBones/Core/Services/ICloudService.swift` и менеджер файлов `LazyBones/Data/DataSources/ICloudFileManager.swift`.
- Экспорт: кнопка в `SettingsView` через `SettingsViewModelNew.exportToICloud()`.
- Не влияет на статусную модель отчетов.

---

## Ключевые различия: regular vs custom

- **Оценка**: есть только у custom (`isEvaluated`, `evaluationResults`).
- **Bad-пункты/теги**: отсутствуют у custom; у regular — есть и управляются через UI переключения good/bad.
- **Сохранение тегов**: custom — всегда как good; regular — по активной вкладке.
- **Статус/таймеры/force unlock**: относятся к regular. Force unlock выполняется из настроек и позволяет редактировать регулярный отчет за сегодня без удаления данных.

---

## Навигация и точки входа

- Главная кнопка «Создать/Редактировать» (на `MainViewNew`) переводит на вкладку Planning (`appCoordinator.switchToTab(.planning)`), где по умолчанию открыт таб `DailyReportView` — форма regular-отчета.
- Список отчетов (`ReportsViewClean`) отображает разделы regular, custom, external и iCloud, с действиями специфичными для типа.

---

## Ссылки (быстрый список файлов)

- Regular: `LazyBones/Views/Forms/RegularReportFormView.swift`, `LazyBones/Views/Forms/DailyReportView.swift`
- Custom/План: `LazyBones/Views/Forms/DailyPlanningFormView.swift`, `LazyBones/Presentation/ViewModels/PlanningViewModel.swift`
- Список отчетов: `LazyBones/Views/ReportsViewClean.swift`
- Главная и навигация: `LazyBones/Views/MainViewNew.swift`, `LazyBones/Views/ContentView.swift`
- Статусная модель/таймеры/force unlock: `LazyBones/Core/Services/ReportStatusManager.swift`, `LazyBones/Presentation/ViewModels/SettingsViewModelNew.swift`, `LazyBones/Views/SettingsView.swift`
- Telegram: `LazyBones/Core/Services/TelegramIntegrationService.swift`, `LazyBones/Presentation/ViewModels/ExternalReportsViewModel.swift`
- iCloud: `LazyBones/Core/Services/ICloudService.swift`, `LazyBones/Data/DataSources/ICloudFileManager.swift`
