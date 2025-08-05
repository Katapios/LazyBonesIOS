# 🚀 Быстрый старт - LazyBones

## 📊 Статус проекта
**Миграция на Clean Architecture: 65% завершено**

## 🎯 Что нужно сделать

### 1. Создать настоящие ViewModels
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
}
```

### 2. Мигрировать Views
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

### 3. Удалить PostStore
- Удалить `PostStore.swift` и `Post.swift`
- Удалить ViewModels-адаптеры
- Обновить `ContentView`

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

## 📁 Ключевые файлы

### Готовые (новая архитектура)
- `ExternalReportsView.swift` - единственный View с новой архитектурой
- `ExternalReportsViewModel.swift` - использует Use Cases
- `RegularReportsViewModel.swift` - использует Use Cases
- `CustomReportsViewModel.swift` - использует Use Cases

### Проблемные (старая архитектура)
- `ContentView.swift` - создает PostStore глобально
- `MainView.swift` - принимает PostStore
- `ReportsView.swift` - принимает PostStore
- `MainViewModel.swift` - оборачивает PostStore
- `ReportsViewModel.swift` - оборачивает PostStore

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

## ⏱️ Время до завершения: 3-4 недели

---

*Быстрый старт*  
*Обновлено: 5 августа 2025* 