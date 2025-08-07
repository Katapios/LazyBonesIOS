# 🏗️ Руководство по созданию сервисов в LazyBones

## 1. Базовая структура сервиса

Каждый сервис должен состоять из следующих компонентов:

```
LazyBones/
├── Domain/
│   ├── Entities/         # Модели данных
│   ├── UseCases/        # Бизнес-логика
│   └── Repositories/    # Протоколы репозиториев
├── Data/
│   ├── Repositories/    # Реализации репозиториев
│   └── DataSources/     # Источники данных
└── Infrastructure/
    └── Services/        # Реализации сервисов
```

## 2. Шаблон сервиса

### 2.1 Доменный слой (Domain)

**Entities/YourEntity.swift**
```swift
struct YourEntity: Identifiable, Codable {
    let id: UUID
    // свойства сущности
}
```

**UseCases/YourUseCaseProtocol.swift**
```swift
protocol YourUseCaseProtocol {
    func execute() async throws -> [YourEntity]
}

final class YourUseCase: YourUseCaseProtocol {
    private let repository: YourRepositoryProtocol
    
    init(repository: YourRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [YourEntity] {
        try await repository.getItems()
    }
}
```

**Repositories/YourRepositoryProtocol.swift**
```swift
protocol YourRepositoryProtocol {
    func getItems() async throws -> [YourEntity]
}
```

### 2.2 Слой данных (Data)

**Repositories/YourRepository.swift**
```swift
final class YourRepository: YourRepositoryProtocol {
    private let dataSource: YourDataSourceProtocol
    
    init(dataSource: YourDataSourceProtocol) {
        self.dataSource = dataSource
    }
    
    func getItems() async throws -> [YourEntity] {
        try await dataSource.fetchItems()
    }
}
```

**DataSources/YourDataSourceProtocol.swift**
```swift
protocol YourDataSourceProtocol {
    func fetchItems() async throws -> [YourEntity]
}
```

### 2.3 Инфраструктурный слой (Infrastructure)

**Services/YourService/YourService.swift**
```swift
final class YourService: YourServiceProtocol {
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol) {
        self.networkManager = networkManager
    }
    
    func fetchData() async throws -> [YourEntity] {
        // реализация
    }
}
```

## 3. Регистрация зависимостей

**DependencyContainer.swift**
```swift
extension DependencyContainer {
    func registerYourServiceDependencies() {
        // DataSources
        register(YourDataSourceProtocol.self) { _ in
            YourDataSource()
        }
        
        // Repositories
        register(YourRepositoryProtocol.self) { resolver in
            YourRepository(
                dataSource: resolver.resolve(YourDataSourceProtocol.self)!
            )
        }
        
        // Use Cases
        register(YourUseCaseProtocol.self) { resolver in
            YourUseCase(
                repository: resolver.resolve(YourRepositoryProtocol.self)!
            )
        }
    }
}
```

## 4. Использование во ViewModel

```swift
@MainActor
final class YourViewModel: ObservableObject {
    @Published private(set) var items: [YourEntity] = []
    @Published private(set) var error: Error?
    
    private let yourUseCase: YourUseCaseProtocol
    
    init(yourUseCase: YourUseCaseProtocol) {
        self.yourUseCase = yourUseCase
    }
    
    func loadData() async {
        do {
            items = try await yourUseCase.execute()
        } catch {
            self.error = error
        }
    }
}
```

## 5. Основные правила

1. **Разделение слоёв**:
   - Domain: Только бизнес-логика
   - Data: Работа с данными
   - Infrastructure: Конкретные реализации

2. **Зависимости**:
   - Внедряйте зависимости через инициализатор
   - Используйте протоколы для всех зависимостей
   - Регистрируйте зависимости в DependencyContainer

3. **Поток данных**:
   View → ViewModel → UseCase → Repository → DataSource

4. **Обработка ошибок**:
   - Используйте кастомные ошибки
   - Обрабатывайте ошибки на уровне ViewModel

5. **Тестирование**:
   - Тестируйте каждый слой изолированно
   - Используйте моки для зависимостей
