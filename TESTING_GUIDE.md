# 🧪 Руководство по тестированию LazyBones

## 📋 Обзор

Это руководство поможет вам понять, как работать с тестами в проекте LazyBones, включая различные типы тестов и их запуск.

## 🎯 Типы тестов

### 1. Unit тесты
**Назначение**: Тестирование отдельных компонентов в изоляции
**Примеры**: 
- `AutoSendServiceTests` - тестирование логики автоотправки
- `CreateReportUseCaseTests` - тестирование бизнес-логики
- `PostRepositoryTests` - тестирование работы с данными
- `RegularReportsViewModelTests` - тестирование ViewModel для обычных отчетов

### 2. Integration тесты
**Назначение**: Тестирование взаимодействия между компонентами
**Примеры**:
- `AutoSendIntegrationTests` - полный flow автоотправки
- `TelegramIntegrationServiceTests` - интеграция с Telegram

### 3. Architecture тесты
**Назначение**: Проверка архитектурных принципов
**Примеры**:
- `ServiceTests` - проверка DI контейнера
- `CoordinatorTests` - тестирование навигации

## 🚀 Запуск тестов

### Через Xcode
1. Откройте проект в Xcode
2. Нажмите `Cmd + U` для запуска всех тестов
3. Или выберите конкретный тест и нажмите `Cmd + U`

### Через командную строку

#### Запуск всех тестов:
```bash
xcodebuild -project LazyBones.xcodeproj -scheme LazyBones -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

#### Запуск конкретного теста:
```bash
xcodebuild -project LazyBones.xcodeproj -scheme LazyBones -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:LazyBonesTests/AutoSendServiceTests
```

#### Запуск конкретного метода теста:
```bash
xcodebuild -project LazyBones.xcodeproj -scheme LazyBones -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:LazyBonesTests/AutoSendServiceTests/testLoadAutoSendSettings
```

## 📁 Структура тестов

```
Tests/
├── AutoSendServiceTests.swift          # Unit тесты автоотправки
├── AutoSendIntegrationTests.swift      # Integration тесты автоотправки
├── TelegramIntegrationServiceTests.swift # Тесты Telegram интеграции
├── ReportStatusManagerTests.swift      # Тесты управления статусами
├── NotificationManagerServiceTests.swift # Тесты уведомлений
├── VoiceRecorderTests.swift            # Тесты записи голоса
├── ArchitectureTests/                  # Архитектурные тесты
│   ├── AppCoordinatorTests.swift
│   ├── CoordinatorTests.swift
│   └── ServiceTests.swift
├── Data/                               # Тесты Data слоя
│   ├── Mappers/
│   │   └── PostMapperTests.swift
│   └── Repositories/
│       └── PostRepositoryTests.swift
├── Domain/                             # Тесты Domain слоя
│   └── UseCases/
│       └── CreateReportUseCaseTests.swift
└── Presentation/                       # Тесты Presentation слоя
    └── ViewModels/
        ├── ReportListViewModelTests.swift
        └── RegularReportsViewModelTests.swift
```

## 🔧 Создание новых тестов

### 1. Unit тест для сервиса

```swift
import XCTest
@testable import LazyBones

@MainActor
class MyServiceTests: XCTestCase {
    
    var myService: MyService!
    var mockDependency: MockDependency!
    
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        myService = MyService(dependency: mockDependency)
    }
    
    override func tearDown() {
        myService = nil
        mockDependency = nil
        super.tearDown()
    }
    
    func testMyServiceFunctionality() {
        // Given
        mockDependency.shouldSucceed = true
        
        // When
        let result = myService.performAction()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockDependency.wasCalled)
    }
}
```

### 2. Integration тест

```swift
import XCTest
@testable import LazyBones

@MainActor
class MyIntegrationTests: XCTestCase {
    
    var dependencyContainer: DependencyContainer!
    var serviceA: ServiceA!
    var serviceB: ServiceB!
    
    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
        dependencyContainer.registerCoreServices()
        
        serviceA = dependencyContainer.resolve(ServiceA.self)
        serviceB = dependencyContainer.resolve(ServiceB.self)
    }
    
    override func tearDown() {
        dependencyContainer = nil
        serviceA = nil
        serviceB = nil
        super.tearDown()
    }
    
    func testServiceAAndBIntegration() async {
        // Given
        let testData = "test"
        
        // When
        let resultA = await serviceA.process(testData)
        let resultB = await serviceB.process(resultA)
        
        // Then
        XCTAssertNotNil(resultA)
        XCTAssertNotNil(resultB)
        XCTAssertEqual(resultB, "expected_result")
    }
}
```

## 🎭 Mock объекты

### Создание Mock для протокола

```swift
class MockMyService: MyServiceProtocol {
    var shouldSucceed = true
    var wasCalled = false
    var lastParameter: String?
    
    func performAction(_ parameter: String) async throws -> Bool {
        wasCalled = true
        lastParameter = parameter
        
        if !shouldSucceed {
            throw NSError(domain: "TestError", code: 500, userInfo: nil)
        }
        
        return true
    }
}
```

### Mock для UserDefaults

```swift
class MockUserDefaultsManager: UserDefaultsManagerProtocol {
    var setCalled = false
    var savedValues: [String: Any] = [:]
    var stringValues: [String: String] = [:]
    var boolValues: [String: Bool] = [:]
    
    func set(_ value: Any?, forKey key: String) {
        setCalled = true
        if let value = value {
            savedValues[key] = value
        }
    }
    
    func string(forKey key: String) -> String? {
        return stringValues[key]
    }
    
    func bool(forKey key: String) -> Bool {
        return boolValues[key] ?? false
    }
}
```

## 🧪 Тестирование автоотправки

### Проверка настроек автоотправки

```swift
func testAutoSendSettings() {
    // Given
    mockUserDefaultsManager.boolValues = ["autoSendToTelegram": true]
    mockUserDefaultsManager.dateValues = ["autoSendTime": Date()]
    
    // When
    autoSendService.loadAutoSendSettings()
    
    // Then
    XCTAssertTrue(autoSendService.autoSendEnabled)
    XCTAssertNotNil(autoSendService.autoSendTime)
}
```

### Проверка полного flow автоотправки

```swift
func testCompleteAutoSendFlow() async {
    // Given
    autoSendService.autoSendEnabled = true
    telegramService.shouldSucceed = true
    
    let testPost = Post(
        id: UUID(),
        date: Date(),
        goodItems: ["Кодил 8 часов"],
        badItems: ["Не гулял"],
        published: false,
        voiceNotes: [],
        type: .regular
    )
    
    // When
    autoSendService.performAutoSendReport()
    
    // Then
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    XCTAssertTrue(telegramService.sendMessageCalled)
    XCTAssertNotNil(telegramService.lastSentText)
}
```

## 📊 Покрытие тестами

### Проверка покрытия

```bash
xcodebuild -project LazyBones.xcodeproj -scheme LazyBones -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -enableCodeCoverage YES
```

### Просмотр отчета о покрытии

После запуска тестов с покрытием, отчет будет доступен в:
```
~/Library/Developer/Xcode/DerivedData/LazyBones-*/Logs/Test/Test-LazyBones-*.xcresult
```

## 🔍 Отладка тестов

### Логирование в тестах

```swift
func testWithLogging() {
    print("🔍 Starting test...")
    
    // Given
    let input = "test"
    print("📥 Input: \(input)")
    
    // When
    let result = service.process(input)
    print("📤 Result: \(result)")
    
    // Then
    XCTAssertNotNil(result)
    print("✅ Test passed!")
}
```

### Асинхронные тесты

```swift
func testAsyncOperation() async throws {
    // Given
    let expectation = XCTestExpectation(description: "Async operation completed")
    
    // When
    Task {
        let result = await service.asyncOperation()
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    // Then
    await fulfillment(of: [expectation], timeout: 5.0)
}
```

## 🚨 Частые проблемы и решения

### 1. Тест не находит класс
**Проблема**: `Could not find 'MyClass' in scope`
**Решение**: Убедитесь, что класс помечен как `public` или `internal`

### 2. Асинхронные тесты не работают
**Проблема**: Тест завершается до завершения асинхронной операции
**Решение**: Используйте `XCTestExpectation` или `await Task.sleep()`

### 3. Mock не вызывается
**Проблема**: Тест использует реальный объект вместо mock
**Решение**: Проверьте DI контейнер и убедитесь, что mock зарегистрирован

### 4. Тест падает в CI
**Проблема**: Тест работает локально, но падает в CI
**Решение**: 
- Добавьте больше времени ожидания для асинхронных операций
- Используйте более стабильные селекторы для UI тестов
- Проверьте зависимости и их доступность

## 📈 Лучшие практики

### 1. Именование тестов
```swift
// ✅ Хорошо
func testLoadAutoSendSettings_WhenDataExists_ShouldLoadCorrectly()

// ❌ Плохо
func test1()
```

### 2. Структура теста (AAA Pattern)
```swift
func testMyFunction() {
    // Arrange (Given)
    let input = "test"
    
    // Act (When)
    let result = service.process(input)
    
    // Assert (Then)
    XCTAssertEqual(result, "expected")
}
```

### 3. Изоляция тестов
```swift
override func setUp() {
    super.setUp()
    // Каждый тест получает чистые объекты
}

override func tearDown() {
    // Очистка после каждого теста
    super.tearDown()
}
```

### 4. Тестирование граничных случаев
```swift
func testWithEmptyInput() { /* ... */ }
func testWithNilInput() { /* ... */ }
func testWithVeryLongInput() { /* ... */ }
func testWithSpecialCharacters() { /* ... */ }
```

## 🎯 Пример: Тестирование автоотправки

Вот полный пример того, как мы тестируем автоотправку:

### 1. Unit тест настроек
```swift
func testLoadAutoSendSettings() {
    // Given
    mockUserDefaultsManager.boolValues = ["autoSendToTelegram": true]
    mockUserDefaultsManager.dateValues = ["autoSendTime": Date()]
    mockUserDefaultsManager.stringValues = ["lastAutoSendStatus": "Success"]
    
    // When
    autoSendService.loadAutoSendSettings()
    
    // Then
    XCTAssertTrue(autoSendService.autoSendEnabled)
    XCTAssertNotNil(autoSendService.autoSendTime)
    XCTAssertEqual(autoSendService.lastAutoSendStatus, "Success")
}
```

### 2. Integration тест полного flow
```swift
func testCompleteAutoSendFlow_RegularReport() async {
    // Given
    autoSendService.autoSendEnabled = true
    telegramService.shouldSucceed = true
    userDefaultsManager.stringValues = ["telegramChatId": "test_chat_id"]
    
    let testPost = Post(
        id: UUID(),
        date: Date(),
        goodItems: ["Кодил 8 часов", "Сделал фичу"],
        badItems: ["Не гулял", "Пропустил спорт"],
        published: false,
        voiceNotes: [],
        type: .regular
    )
    
    let encodedData = try! JSONEncoder().encode([testPost])
    userDefaultsManager.dataValues = ["posts": encodedData]
    
    // When
    autoSendService.performAutoSendReport()
    
    // Then
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    
    XCTAssertTrue(telegramService.sendMessageCalled)
    XCTAssertNotNil(telegramService.lastSentText)
    
    let sentText = telegramService.lastSentText ?? ""
    XCTAssertTrue(sentText.contains("Кодил 8 часов"))
    XCTAssertTrue(sentText.contains("Сделал фичу"))
    XCTAssertTrue(sentText.contains("Не гулял"))
    XCTAssertTrue(sentText.contains("Пропустил спорт"))
}
```

## 📚 Дополнительные ресурсы

- [XCTest Framework Documentation](https://developer.apple.com/documentation/xctest)
- [Testing with Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [Swift Testing Best Practices](https://www.swift.org/documentation/testing/)

## 🤝 Вклад в тестирование

При добавлении новой функциональности:

1. **Создайте unit тесты** для новой логики
2. **Добавьте integration тесты** для проверки взаимодействий
3. **Обновите документацию** с примерами использования
4. **Проверьте покрытие** и добавьте тесты для недостающих сценариев

---

*Это руководство поможет вам эффективно работать с тестами в проекте LazyBones и поддерживать высокое качество кода.* 