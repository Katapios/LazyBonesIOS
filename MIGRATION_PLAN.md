# 🏗️ План миграции на Clean Architecture

## 📊 Статус: 80% завершено

**Дата**: 5 августа 2025  
**Статус**: Domain/Data готовы, Presentation в процессе

## ✅ Что готово

### Domain Layer (100%)
- `DomainPost`, `DomainVoiceNote`, `ReportStatus`
- Все Use Cases: `CreateReportUseCase`, `GetReportsUseCase`, etc.
- Repository Protocols: `PostRepositoryProtocol`, `TagRepositoryProtocol`

### Data Layer (100%)
- `PostRepository`, `TagRepository`, `SettingsRepository`
- `UserDefaultsPostDataSource`, `ICloudFileManager`
- `PostMapper`, `VoiceNoteMapper`

### Infrastructure Layer (100%)
- Все сервисы: `TelegramService`, `NotificationService`, etc.
- `DependencyContainer` настроен
- `AppCoordinator` работает

### Presentation Layer (30%)
- ✅ ViewModels с новой архитектурой: `RegularReportsViewModel`, `CustomReportsViewModel`, `ExternalReportsViewModel`
- ✅ Единственный View с новой архитектурой: `ExternalReportsView`
- ❌ ViewModels-адаптеры: `MainViewModel`, `ReportsViewModel`, `SettingsViewModel` (оборачивают PostStore)
- ❌ Views используют PostStore: `MainView`, `ReportsView`, `SettingsView`

## 🚨 Критические проблемы

### 1. PostStore как глобальное состояние
```swift
// ContentView.swift - корень проблемы
@StateObject var store = PostStore() // Глобальное состояние
MainView(store: store) // Передача PostStore
.environmentObject(store) // Environment Object
```

### 2. ViewModels-адаптеры вместо настоящих ViewModels
```swift
// Это НЕ Clean Architecture:
class MainViewModel: ObservableObject {
    @Published var store: PostStore // Прямая зависимость!
}
```

### 3. Смешанная архитектура
```swift
// НОВАЯ архитектура:
ExternalReportsView(viewModel: ExternalReportsViewModel) // ✅
MainViewNew() // ✅

// СТАРАЯ архитектура:
MainView(store: PostStore) // ❌
```

## 🎯 Что нужно сделать

### Шаг 1: Создать настоящие ViewModels (КРИТИЧНО)
```swift
// MainViewModel с новой архитектурой
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
        }
    }
}
```

### Шаг 2: Мигрировать Views
```swift
// MainView с новой архитектурой
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

### Шаг 3: Обновить ContentView
```swift
struct ContentView: View {
    @StateObject var appCoordinator: AppCoordinator
    // УДАЛИТЬ: @StateObject var store = PostStore()
    
    var body: some View {
        TabView(selection: $appCoordinator.currentTab) {
            NavigationStack(path: $appCoordinator.navigationPath) {
                MainView() // БЕЗ store!
            }
            .tabItem { ... }
            
            NavigationStack(path: $appCoordinator.navigationPath) {
                ReportsView() // БЕЗ store!
            }
            .tabItem { ... }
        }
        // УДАЛИТЬ: .environmentObject(store)
    }
}
```

### Шаг 4: Удалить PostStore
- Удалить `PostStore.swift`
- Удалить `Post.swift` (оставить только `DomainPost`)
- Удалить ViewModels-адаптеры
- Обновить все импорты

## 📋 Быстрый чек-лист

### Создать ViewModels (1-2 недели)
- [ ] `MainViewModel` с `BaseViewModel<MainState, MainEvent>`
- [ ] `ReportsViewModel` с `BaseViewModel<ReportsState, ReportsEvent>`
- [ ] `SettingsViewModel` с `BaseViewModel<SettingsState, SettingsEvent>`
- [ ] `TagManagerViewModel` с `BaseViewModel<TagManagerState, TagManagerEvent>`

### Мигрировать Views (1-2 недели)
- [ ] `MainView` - убрать `store: PostStore`
- [ ] `ReportsView` - убрать `store: PostStore`
- [ ] `SettingsView` - убрать `store: PostStore`
- [ ] `TagManagerView` - убрать `store: PostStore`

### Очистка (1 неделя)
- [ ] Обновить `ContentView` - убрать PostStore
- [ ] Удалить PostStore и Post модели
- [ ] Удалить ViewModels-адаптеры
- [ ] Обновить DI контейнер

## 📁 Ключевые файлы

### Готовые (новая архитектура)
- `ExternalReportsView.swift`, `MainViewNew.swift` — Views с новой архитектурой
- `ExternalReportsViewModel.swift` - использует Use Cases
- `RegularReportsViewModel.swift` - использует Use Cases
- `CustomReportsViewModel.swift` - использует Use Cases

### Проблемные (старая архитектура)
- `ContentView.swift` - создает PostStore глобально
- `MainView.swift` - принимает PostStore
- `ReportsView.swift` - принимает PostStore
- `MainViewModel.swift` - оборачивает PostStore
- `ReportsViewModel.swift` - оборачивает PostStore

## ⏱️ Время до завершения: 3-4 недели

---

*План миграции*  
*Обновлено: 5 августа 2025* 