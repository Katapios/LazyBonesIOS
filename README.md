# 📱 LazyBones - Приложение для ежедневных отчетов

**LazyBones** - iOS приложение для создания и отправки ежедневных отчетов о продуктивности с интеграцией Telegram.

**🔄 Статус**: Миграция на Clean Architecture - 80% завершено

## 🏗️ Архитектура

### ✅ Готово (100%)
- **Domain Layer**: Entities, Use Cases, Repository Protocols
- **Data Layer**: Repositories, Data Sources, Mappers  
- **Infrastructure Layer**: Services, DI Container, Coordinators

### 🔄 В процессе (50%)
- **Presentation Layer**: ViewModels готовы частично, Views в миграции

## 🚨 Критические проблемы

### PostStore как глобальное состояние
```swift
// ContentView.swift - корень проблемы
@StateObject var store = PostStore() // Глобальное состояние
MainView(store: store) // Передача PostStore
```

### Смешанная архитектура
```swift
// НОВАЯ архитектура:
ExternalReportsView(viewModel: ExternalReportsViewModel) // ✅

// СТАРАЯ архитектура:
MainView(store: PostStore) // ❌
```

## 🎯 Что нужно сделать

### 1. Создать настоящие ViewModels
```swift
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
}
```

### 2. Мигрировать Views
```swift
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

### 3. Удалить PostStore
- Удалить `PostStore.swift` и `Post.swift`
- Удалить ViewModels-адаптеры
- Обновить `ContentView`

## 📋 Быстрый чек-лист

### Создать ViewModels (1-2 недели)
- [x] `MainViewModelNew` с `BaseViewModel<MainState, MainEvent>` ✅
- [x] `ReportsViewModelNew` с `BaseViewModel<ReportsState, ReportsEvent>` ✅
- [x] `SettingsViewModelNew` с `BaseViewModel<SettingsState, SettingsEvent>` ✅ (см. SETTINGS_MIGRATION.md)
- [ ] `TagManagerViewModel` с `BaseViewModel<TagManagerState, TagManagerEvent>`

### Мигрировать Views (1-2 недели)
- [x] `MainViewNew` - новый с Clean Architecture ✅
- [ ] `MainView` - заменить на MainViewNew
- [ ] `ReportsViewNew` - создать новый с Clean Architecture
- [ ] `ReportsView` - заменить на ReportsViewNew
- [x] `SettingsView` - переведён на `SettingsViewModelNew`, без `PostStore` ✅
- [ ] `TagManagerView` - убрать `store: PostStore`

### Очистка (1 неделя)
- [ ] Обновить `ContentView` - убрать PostStore
- [ ] Удалить PostStore и Post модели
- [ ] Удалить ViewModels-адаптеры

## 📁 Ключевые файлы

### Готовые (новая архитектура)
- `ExternalReportsView.swift`, `MainViewNew.swift` — Views, мигрированные на Clean Architecture
- `ExternalReportsViewModel.swift` - использует Use Cases
- `RegularReportsViewModel.swift` - использует Use Cases
- `CustomReportsViewModel.swift` - использует Use Cases
- `MainViewModelNew.swift` - новый с Clean Architecture
- `ReportsViewModelNew.swift` - новый с Clean Architecture
- `MainViewNew.swift` - новый View с Clean Architecture
- `SettingsViewModelNew.swift` и связанные представления/координатор (см. SETTINGS_MIGRATION.md)

### Проблемные (старая архитектура)
- `ContentView.swift` - создает PostStore глобально
- `MainView.swift` - принимает PostStore
- `ReportsView.swift` - принимает PostStore
- `MainViewModel.swift` - оборачивает PostStore
- `ReportsViewModel.swift` - оборачивает PostStore

## 🧪 Тестирование

**Покрытие тестами**: ~90%
- ✅ Unit тесты для Domain/Data слоев
- ✅ Unit тесты для ViewModels с новой архитектурой
- ✅ Integration тесты

Дополнительно:
- `SettingsViewModelNewTests.swift` покрывает уведомления, Telegram, экспорт iCloud, автоотправку, разблокировку отчёта

Подробнее: см. `SETTINGS_MIGRATION.md`

## 🚀 Установка

```bash
git clone https://github.com/your-username/LazyBonesIOS.git
cd LazyBonesIOS
open LazyBones.xcodeproj
```

## 📱 Основные функции

- 📝 Создание ежедневных отчетов
- 📋 Планирование и оценка задач
- 📨 Интеграция с Telegram
- 🔔 Автоматические уведомления
- ☁️ iCloud синхронизация

## ⏱️ Время до завершения: 3-4 недели

---

**🔄 Проект в активной разработке. Миграция на Clean Architecture: 80% завершено.**
