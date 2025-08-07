# 🏗️ Руководство по созданию сервисов в LazyBones

## 1. Базовая структура сервиса

```
LazyBones/
├── Domain/
│   ├── Entities/         # Модели данных (DomainPost, DomainVoiceNote)
│   ├── UseCases/        # Бизнес-логика
│   └── Repositories/    # Протоколы репозиториев
├── Data/
│   ├── Repositories/    # Реализации репозиториев
│   └── DataSources/     # Источники данных (CoreData, Network)
└── Infrastructure/
    └── Services/        # Внешние сервисы (Telegram, iCloud)
```

## 2. Шаблон сервиса

### 2.1 Доменный слой (Domain)

**Entities/YourEntity.swift**
```swift
import Foundation

struct YourEntity: Identifiable, Codable {
    let id: UUID
    // Свойства сущности
    let createdAt: Date
    var isActive: Bool
    
    // Добавьте кастомный инициализатор при необходимости
    init(id: UUID = UUID(), 
         createdAt: Date = Date(),
         isActive: Bool = true) {
        self.id = id
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

// MARK: - Domain Errors
enum YourEntityError: Error, LocalizedError {
    case notFound
    case validationFailed(String)
    case repositoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Объект не найден"
        case .validationFailed(let message):
            return "Ошибка валидации: \(message)"
        case .repositoryError(let error):
            return "Ошибка репозитория: \(error.localizedDescription)"
        }
    }
}
```

**UseCases/YourUseCaseProtocol.swift**
```swift
import Foundation

/// Входные данные для Use Case
struct YourUseCaseInput {
    // Параметры запроса
    let filter: String?
    let includeInactive: Bool
    
    init(filter: String? = nil, includeInactive: Bool = false) {
        self.filter = filter
        self.includeInactive = includeInactive
    }
}

/// Протокол Use Case
protocol YourUseCaseProtocol: UseCaseProtocol where
    Input == YourUseCaseInput,
    Output == [YourEntity],
    ErrorType == YourEntityError {
}

/// Реализация Use Case
final class YourUseCase: YourUseCaseProtocol {
    private let repository: YourRepositoryProtocol
    
    init(repository: YourRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: YourUseCaseInput) async throws -> [YourEntity] {
        do {
            let items = try await repository.fetchItems()
            return items.filter { item in
                // Применяем фильтры
                let matchesFilter = input.filter.map { item.id.uuidString.contains($0) } ?? true
                let isActive = input.includeInactive || item.isActive
                return matchesFilter && isActive
            }
        } catch {
            throw YourEntityError.repositoryError(error)
        }
    }
}
```

**Repositories/YourRepositoryProtocol.swift**
```swift
import Foundation

/// Протокол репозитория для работы с сущностями
protocol YourRepositoryProtocol {
    /// Получить все элементы
    func fetchItems() async throws -> [YourEntity]
    
    /// Сохранить элемент
    /// - Parameter item: Элемент для сохранения
    func saveItem(_ item: YourEntity) async throws
    
    /// Удалить элемент
    /// - Parameter id: Идентификатор элемента
    func deleteItem(withId id: UUID) async throws
    
    /// Обновить элемент
    /// - Parameter item: Обновленный элемент
    func updateItem(_ item: YourEntity) async throws
}
```

### 2.2 Слой данных (Data)

**Repositories/YourRepository.swift**
```swift
import Foundation

final class YourRepository: YourRepositoryProtocol {
    private let dataSource: YourDataSourceProtocol
    private let mapper: YourEntityMapper
    
    init(dataSource: YourDataSourceProtocol, 
         mapper: YourEntityMapper = .init()) {
        self.dataSource = dataSource
        self.mapper = mapper
    }
    
    func fetchItems() async throws -> [YourEntity] {
        let dtos = try await dataSource.fetchItems()
        return dtos.map { mapper.map($0) }
    }
    
    func saveItem(_ item: YourEntity) async throws {
        let dto = mapper.map(item)
        try await dataSource.saveItem(dto)
    }
    
    func deleteItem(withId id: UUID) async throws {
        try await dataSource.deleteItem(withId: id)
    }
    
    func updateItem(_ item: YourEntity) async throws {
        let dto = mapper.map(item)
        try await dataSource.updateItem(dto)
    }
}

// MARK: - Mapper
struct YourEntityMapper {
    func map(_ dto: YourEntityDTO) -> YourEntity {
        YourEntity(
            id: dto.id,
            createdAt: dto.createdAt,
            isActive: dto.isActive
        )
    }
    
    func map(_ entity: YourEntity) -> YourEntityDTO {
        YourEntityDTO(
            id: entity.id,
            createdAt: entity.createdAt,
            isActive: entity.isActive
        )
    }
}
```

**DataSources/YourDataSourceProtocol.swift**
```swift
import Foundation

/// Протокол источника данных
protocol YourDataSourceProtocol {
    func fetchItems() async throws -> [YourEntityDTO]
    func saveItem(_ item: YourEntityDTO) async throws
    func deleteItem(withId id: UUID) async throws
    func updateItem(_ item: YourEntityDTO) async throws
}

/// DTO для работы с источником данных
struct YourEntityDTO: Codable {
    let id: UUID
    let createdAt: Date
    var isActive: Bool
}
```

### 2.3 Инфраструктурный слой (Infrastructure)

**Services/YourService/YourService.swift**
```swift
import Foundation

/// Протокол сервиса
protocol YourServiceProtocol {
    func performOperation() async throws -> [YourEntity]
}

final class YourService: YourServiceProtocol {
    private let networkManager: NetworkManagerProtocol
    private let yourUseCase: YourUseCaseProtocol
    
    init(
        networkManager: NetworkManagerProtocol,
        yourUseCase: YourUseCaseProtocol
    ) {
        self.networkManager = networkManager
        self.yourUseCase = yourUseCase
    }
    
    func performOperation() async throws -> [YourEntity] {
        // Пример интеграции с внешним сервисом
        let data = try await networkManager.request(
            endpoint: .yourEndpoint,
            method: .get
        )
        
        // Обработка данных и возврат результата
        return try await yourUseCase.execute(
            input: .init(/* параметры */)
        )
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
            YourCoreDataDataSource(
                context: self.resolve(NSManagedObjectContext.self)!
            )
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
        
        // Services
        register(YourServiceProtocol.self) { resolver in
            YourService(
                networkManager: resolver.resolve(NetworkManagerProtocol.self)!,
                yourUseCase: resolver.resolve(YourUseCaseProtocol.self)!
            )
        }
    }
}
```

## 4. Использование во ViewModel

```swift
import SwiftUI
import Combine

@MainActor
final class YourViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var items: [YourEntity] = []
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let yourUseCase: YourUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(yourUseCase: YourUseCaseProtocol) {
        self.yourUseCase = yourUseCase
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadItems() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            items = try await yourUseCase.execute(
                input: .init(/* параметры */)
            )
        } catch {
            self.error = error
            Logger.error("Failed to load items: \(error)", log: .yourFeature)
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        $error
            .compactMap { $0?.localizedDescription }
            .sink { errorMessage in
                // Показываем ошибку пользователю
                print("Error: \(errorMessage)")
            }
            .store(in: &cancellables)
    }
}
```

## 5. Основные правила и лучшие практики

### 1. Принципы проектирования
- **SOLID**: Соблюдайте принципы SOLID
- **DRY**: Избегайте дублирования кода
- **KISS**: Делайте код максимально простым
- **YAGNI**: Не добавляйте функционал "на будущее"

### 2. Асинхронность
- Используйте `async/await` для асинхронных операций
- Избегайте блокирующих операций в главном потоке
- Используйте `Task` для вызова асинхронного кода из синхронных методов

### 3. Обработка ошибок
- Создавайте кастомные ошибки в доменном слое
- Преобразуйте ошибки из нижних слоев в доменные ошибки
- Логируйте ошибки с контекстом

### 4. Тестирование
- Покрывайте тестами все Use Cases
- Используйте моки для зависимостей
- Тестируйте граничные случаи

### 5. Производительность
- Используйте `@MainActor` для обновления UI
- Оптимизируйте загрузку данных
- Кэшируйте часто используемые данные

### 6. Безопасность
- Не храните чувствительные данные в коде
- Используйте Keychain для хранения токенов
- Валидируйте все входящие данные
