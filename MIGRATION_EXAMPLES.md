# 📝 Примеры кода для миграции к Clean Architecture

## 🎯 Фаза 1: Подготовка

### 1.1 Базовая структура папок

```bash
# Создание структуры папок
mkdir -p LazyBones/Domain/Entities
mkdir -p LazyBones/Domain/UseCases
mkdir -p LazyBones/Domain/Repositories
mkdir -p LazyBones/Data/Repositories
mkdir -p LazyBones/Data/DataSources
mkdir -p LazyBones/Data/Models
mkdir -p LazyBones/Presentation/ViewModels
mkdir -p LazyBones/Presentation/Views
mkdir -p LazyBones/Presentation/Coordinators
mkdir -p LazyBones/Infrastructure/Services
mkdir -p LazyBones/Infrastructure/Persistence
mkdir -p LazyBones/Infrastructure/DI
```

### 1.2 Базовые протоколы

```swift
// Domain/Common/UseCaseProtocol.swift
protocol UseCaseProtocol {
    associatedtype Input
    associatedtype Output
    associatedtype ErrorType: Error
    
    func execute(input: Input) async throws -> Output
}

// Domain/Common/RepositoryProtocol.swift
protocol RepositoryProtocol {
    associatedtype Model
    associatedtype ErrorType: Error
    
    func save(_ model: Model) async throws
    func fetch() async throws -> [Model]
    func delete(_ model: Model) async throws
    func update(_ model: Model) async throws
}

// Domain/Common/DataSourceProtocol.swift
protocol DataSourceProtocol {
    associatedtype Model
    associatedtype ErrorType: Error
    
    func save(_ models: [Model]) async throws
    func load() async throws -> [Model]
    func clear() async throws
}
```

## 🎯 Фаза 2: Domain Layer

### 2.1 Domain Entities

```swift
// Domain/Entities/Post.swift
struct Post: Identifiable, Equatable {
    let id: UUID
    let date: Date
    var goodItems: [String]
    var badItems: [String]
    var published: Bool
    var voiceNotes: [VoiceNote]
    var type: PostType
    var isEvaluated: Bool?
    var evaluationResults: [Bool]?
    
    // Telegram integration fields
    var authorUsername: String?
    var authorFirstName: String?
    var authorLastName: String?
    var isExternal: Bool?
    var externalVoiceNoteURLs: [URL]?
    var externalText: String?
    var externalMessageId: Int?
    var authorId: Int?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        goodItems: [String] = [],
        badItems: [String] = [],
        published: Bool = false,
        voiceNotes: [VoiceNote] = [],
        type: PostType = .regular,
        isEvaluated: Bool? = nil,
        evaluationResults: [Bool]? = nil,
        authorUsername: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        isExternal: Bool? = nil,
        externalVoiceNoteURLs: [URL]? = nil,
        externalText: String? = nil,
        externalMessageId: Int? = nil,
        authorId: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.goodItems = goodItems
        self.badItems = badItems
        self.published = published
        self.voiceNotes = voiceNotes
        self.type = type
        self.isEvaluated = isEvaluated
        self.evaluationResults = evaluationResults
        self.authorUsername = authorUsername
        self.authorFirstName = authorFirstName
        self.authorLastName = authorLastName
        self.isExternal = isExternal
        self.externalVoiceNoteURLs = externalVoiceNoteURLs
        self.externalText = externalText
        self.externalMessageId = externalMessageId
        self.authorId = authorId
    }
}

// Domain/Entities/VoiceNote.swift
struct VoiceNote: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    
    init(id: UUID = UUID(), url: URL, duration: TimeInterval, createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.duration = duration
        self.createdAt = createdAt
    }
}

// Domain/Entities/PostType.swift
enum PostType: String, CaseIterable {
    case regular = "regular"
    case custom = "custom"
    case external = "external"
    
    var displayName: String {
        switch self {
        case .regular: return "Обычный отчет"
        case .custom: return "Кастомный отчет"
        case .external: return "Внешний отчет"
        }
    }
}

// Domain/Entities/ReportStatus.swift
enum ReportStatus: String, CaseIterable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case sent = "sent"
    case notCreated = "notCreated"
    case notSent = "notSent"
    case done = "done"
    
    var displayName: String {
        switch self {
        case .notStarted: return "Заполни отчет"
        case .inProgress: return "Отчет заполняется..."
        case .sent: return "Отчет отправлен"
        case .notCreated: return "Отчёт не создан"
        case .notSent: return "Отчёт не отправлен"
        case .done: return "Завершен"
        }
    }
}

// Domain/Entities/TagCategory.swift
enum TagCategory: String, CaseIterable {
    case good = "good"
    case bad = "bad"
    
    var displayName: String {
        switch self {
        case .good: return "Хорошие"
        case .bad: return "Плохие"
        }
    }
}
```

### 2.2 Use Cases

```swift
// Domain/UseCases/CreateReportUseCase.swift
struct CreateReportInput {
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [VoiceNote]
    let type: PostType
    let isEvaluated: Bool?
    let evaluationResults: [Bool]?
}

protocol CreateReportUseCaseProtocol: UseCaseProtocol where
    Input == CreateReportInput,
    Output == Post,
    ErrorType == ReportError {
    func execute(input: Input) async throws -> Output
}

class CreateReportUseCase: CreateReportUseCaseProtocol {
    private let repository: PostRepositoryProtocol
    
    init(repository: PostRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: CreateReportInput) async throws -> Post {
        // Валидация входных данных
        guard !input.goodItems.isEmpty || !input.badItems.isEmpty else {
            throw ReportError.validationFailed("Отчет должен содержать хотя бы один пункт")
        }
        
        // Создание отчета
        let post = Post(
            goodItems: input.goodItems,
            badItems: input.badItems,
            voiceNotes: input.voiceNotes,
            type: input.type,
            isEvaluated: input.isEvaluated,
            evaluationResults: input.evaluationResults
        )
        
        // Сохранение отчета
        try await repository.save(post)
        
        return post
    }
}

// Domain/UseCases/GetReportsUseCase.swift
protocol GetReportsUseCaseProtocol: UseCaseProtocol where
    Input == Void,
    Output == [Post],
    ErrorType == ReportError {
    func execute(input: Input) async throws -> Output
}

class GetReportsUseCase: GetReportsUseCaseProtocol {
    private let repository: PostRepositoryProtocol
    
    init(repository: PostRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(input: Void) async throws -> [Post] {
        return try await repository.fetch()
    }
}

// Domain/UseCases/UpdateStatusUseCase.swift
protocol UpdateStatusUseCaseProtocol: UseCaseProtocol where
    Input == Void,
    Output == ReportStatus,
    ErrorType == ReportError {
    func execute(input: Input) async throws -> Output
}

class UpdateStatusUseCase: UpdateStatusUseCaseProtocol {
    private let repository: PostRepositoryProtocol
    private let timeProvider: TimeProviderProtocol
    
    init(repository: PostRepositoryProtocol, timeProvider: TimeProviderProtocol) {
        self.repository = repository
        self.timeProvider = timeProvider
    }
    
    func execute(input: Void) async throws -> ReportStatus {
        let posts = try await repository.fetch()
        let now = timeProvider.currentDate()
        
        // Логика определения статуса
        let hasRegularReport = posts.contains { $0.type == .regular && Calendar.current.isDateInToday($0.date) }
        let isPeriodActive = isReportPeriodActive(now: now)
        
        if hasRegularReport {
            let regularPost = posts.first { $0.type == .regular && Calendar.current.isDateInToday($0.date) }!
            if isPeriodActive {
                return regularPost.published ? .sent : .inProgress
            } else {
                return regularPost.published ? .sent : .notSent
            }
        } else {
            return isPeriodActive ? .notStarted : .notCreated
        }
    }
    
    private func isReportPeriodActive(now: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        return hour >= 8 && hour < 22
    }
}

// Domain/UseCases/SendReportUseCase.swift
struct SendReportInput {
    let post: Post
    let message: String
}

protocol SendReportUseCaseProtocol: UseCaseProtocol where
    Input == SendReportInput,
    Output == Bool,
    ErrorType == ReportError {
    func execute(input: Input) async throws -> Output
}

class SendReportUseCase: SendReportUseCaseProtocol {
    private let repository: PostRepositoryProtocol
    private let telegramService: TelegramServiceProtocol
    
    init(repository: PostRepositoryProtocol, telegramService: TelegramServiceProtocol) {
        self.repository = repository
        self.telegramService = telegramService
    }
    
    func execute(input: SendReportInput) async throws -> Bool {
        // Отправка в Telegram
        let success = try await telegramService.sendMessage(input.message)
        
        if success {
            // Обновление статуса отчета
            var updatedPost = input.post
            updatedPost.published = true
            try await repository.update(updatedPost)
        }
        
        return success
    }
}
```

### 2.3 Repository интерфейсы

```swift
// Domain/Repositories/PostRepositoryProtocol.swift
protocol PostRepositoryProtocol: RepositoryProtocol where
    Model == Post,
    ErrorType == ReportError {
    func save(_ post: Post) async throws
    func fetch() async throws -> [Post]
    func fetch(for date: Date) async throws -> [Post]
    func delete(_ post: Post) async throws
    func update(_ post: Post) async throws
    func clear() async throws
}

// Domain/Repositories/TagRepositoryProtocol.swift
protocol TagRepositoryProtocol: RepositoryProtocol where
    Model == String,
    ErrorType == ReportError {
    func save(_ tags: [String], category: TagCategory) async throws
    func fetch(category: TagCategory) async throws -> [String]
    func delete(_ tag: String, category: TagCategory) async throws
    func update(old: String, new: String, category: TagCategory) async throws
}

// Domain/Repositories/ReportStatusRepositoryProtocol.swift
protocol ReportStatusRepositoryProtocol: RepositoryProtocol where
    Model == ReportStatus,
    ErrorType == ReportError {
    func save(_ status: ReportStatus) async throws
    func fetch() async throws -> ReportStatus
}
```

### 2.4 Domain Errors

```swift
// Domain/Common/ReportError.swift
enum ReportError: Error, LocalizedError {
    case validationFailed(String)
    case networkError(String)
    case storageError(String)
    case telegramError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Ошибка валидации: \(message)"
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .storageError(let message):
            return "Ошибка хранения: \(message)"
        case .telegramError(let message):
            return "Ошибка Telegram: \(message)"
        case .unknownError(let message):
            return "Неизвестная ошибка: \(message)"
        }
    }
}

// Domain/Common/TimeProviderProtocol.swift
protocol TimeProviderProtocol {
    var currentDate: Date { get }
}

class TimeProvider: TimeProviderProtocol {
    var currentDate: Date {
        return Date()
    }
}
```

## 🎯 Фаза 3: Data Layer

### 3.1 Data Models (DTOs)

```swift
// Data/Models/PostDTO.swift
struct PostDTO: Codable {
    let id: String
    let date: String
    let goodItems: [String]
    let badItems: [String]
    let published: Bool
    let voiceNotes: [VoiceNoteDTO]
    let type: String
    let isEvaluated: Bool?
    let evaluationResults: [Bool]?
    let authorUsername: String?
    let authorFirstName: String?
    let authorLastName: String?
    let isExternal: Bool?
    let externalVoiceNoteURLs: [String]?
    let externalText: String?
    let externalMessageId: Int?
    let authorId: Int?
    
    init(from domain: Post) {
        self.id = domain.id.uuidString
        self.date = ISO8601DateFormatter().string(from: domain.date)
        self.goodItems = domain.goodItems
        self.badItems = domain.badItems
        self.published = domain.published
        self.voiceNotes = domain.voiceNotes.map { VoiceNoteDTO(from: $0) }
        self.type = domain.type.rawValue
        self.isEvaluated = domain.isEvaluated
        self.evaluationResults = domain.evaluationResults
        self.authorUsername = domain.authorUsername
        self.authorFirstName = domain.authorFirstName
        self.authorLastName = domain.authorLastName
        self.isExternal = domain.isExternal
        self.externalVoiceNoteURLs = domain.externalVoiceNoteURLs?.map { $0.absoluteString }
        self.externalText = domain.externalText
        self.externalMessageId = domain.externalMessageId
        self.authorId = domain.authorId
    }
    
    func toDomain() -> Post {
        return Post(
            id: UUID(uuidString: id) ?? UUID(),
            date: ISO8601DateFormatter().date(from: date) ?? Date(),
            goodItems: goodItems,
            badItems: badItems,
            published: published,
            voiceNotes: voiceNotes.map { $0.toDomain() },
            type: PostType(rawValue: type) ?? .regular,
            isEvaluated: isEvaluated,
            evaluationResults: evaluationResults,
            authorUsername: authorUsername,
            authorFirstName: authorFirstName,
            authorLastName: authorLastName,
            isExternal: isExternal,
            externalVoiceNoteURLs: externalVoiceNoteURLs?.compactMap { URL(string: $0) },
            externalText: externalText,
            externalMessageId: externalMessageId,
            authorId: authorId
        )
    }
}

// Data/Models/VoiceNoteDTO.swift
struct VoiceNoteDTO: Codable {
    let id: String
    let url: String
    let duration: Double
    let createdAt: String
    
    init(from domain: VoiceNote) {
        self.id = domain.id.uuidString
        self.url = domain.url.absoluteString
        self.duration = domain.duration
        self.createdAt = ISO8601DateFormatter().string(from: domain.createdAt)
    }
    
    func toDomain() -> VoiceNote {
        return VoiceNote(
            id: UUID(uuidString: id) ?? UUID(),
            url: URL(string: url) ?? URL(fileURLWithPath: ""),
            duration: duration,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}
```

### 3.2 Data Sources

```swift
// Data/DataSources/LocalDataSourceProtocol.swift
protocol LocalDataSourceProtocol: DataSourceProtocol where
    Model == PostDTO,
    ErrorType == ReportError {
    func savePosts(_ posts: [PostDTO]) async throws
    func loadPosts() async throws -> [PostDTO]
    func saveTags(_ tags: [String], category: TagCategory) async throws
    func loadTags(category: TagCategory) async throws -> [String]
    func saveReportStatus(_ status: String) async throws
    func loadReportStatus() async throws -> String
    func clearAll() async throws
}

// Data/DataSources/LocalDataSourceImpl.swift
class LocalDataSourceImpl: LocalDataSourceProtocol {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(userDefaults: UserDefaults = UserDefaults(suiteName: AppConfig.appGroup) ?? UserDefaults.standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    func savePosts(_ posts: [PostDTO]) async throws {
        do {
            let data = try encoder.encode(posts)
            userDefaults.set(data, forKey: "posts")
            userDefaults.synchronize()
        } catch {
            throw ReportError.storageError("Не удалось сохранить отчеты: \(error.localizedDescription)")
        }
    }
    
    func loadPosts() async throws -> [PostDTO] {
        guard let data = userDefaults.data(forKey: "posts") else {
            return []
        }
        
        do {
            return try decoder.decode([PostDTO].self, from: data)
        } catch {
            throw ReportError.storageError("Не удалось загрузить отчеты: \(error.localizedDescription)")
        }
    }
    
    func saveTags(_ tags: [String], category: TagCategory) async throws {
        do {
            let data = try encoder.encode(tags)
            userDefaults.set(data, forKey: "tags_\(category.rawValue)")
            userDefaults.synchronize()
        } catch {
            throw ReportError.storageError("Не удалось сохранить теги: \(error.localizedDescription)")
        }
    }
    
    func loadTags(category: TagCategory) async throws -> [String] {
        guard let data = userDefaults.data(forKey: "tags_\(category.rawValue)") else {
            return []
        }
        
        do {
            return try decoder.decode([String].self, from: data)
        } catch {
            throw ReportError.storageError("Не удалось загрузить теги: \(error.localizedDescription)")
        }
    }
    
    func saveReportStatus(_ status: String) async throws {
        userDefaults.set(status, forKey: "reportStatus")
        userDefaults.synchronize()
    }
    
    func loadReportStatus() async throws -> String {
        return userDefaults.string(forKey: "reportStatus") ?? ReportStatus.notStarted.rawValue
    }
    
    func clearAll() async throws {
        userDefaults.removeObject(forKey: "posts")
        userDefaults.removeObject(forKey: "tags_good")
        userDefaults.removeObject(forKey: "tags_bad")
        userDefaults.removeObject(forKey: "reportStatus")
        userDefaults.synchronize()
    }
}

// Data/DataSources/RemoteDataSourceProtocol.swift
protocol RemoteDataSourceProtocol: DataSourceProtocol where
    Model == TelegramMessage,
    ErrorType == ReportError {
    func sendMessage(_ message: String) async throws -> Bool
    func getUpdates() async throws -> [TelegramMessage]
    func sendVoice(_ voiceData: Data, filename: String) async throws -> Bool
}

// Data/Models/TelegramMessage.swift
struct TelegramMessage: Codable {
    let messageId: Int
    let text: String?
    let voice: TelegramVoice?
    let from: TelegramUser
    let date: Int
    
    struct TelegramVoice: Codable {
        let fileId: String
        let duration: Int
        let mimeType: String?
        let fileSize: Int?
    }
    
    struct TelegramUser: Codable {
        let id: Int
        let firstName: String
        let lastName: String?
        let username: String?
    }
}
```

### 3.3 Repository реализации

```swift
// Data/Repositories/PostRepositoryImpl.swift
class PostRepositoryImpl: PostRepositoryProtocol {
    private let localDataSource: LocalDataSourceProtocol
    private let remoteDataSource: RemoteDataSourceProtocol
    
    init(localDataSource: LocalDataSourceProtocol, remoteDataSource: RemoteDataSourceProtocol) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    func save(_ post: Post) async throws {
        let dto = PostDTO(from: post)
        let posts = try await localDataSource.loadPosts()
        var updatedPosts = posts.filter { $0.id != dto.id }
        updatedPosts.append(dto)
        try await localDataSource.savePosts(updatedPosts)
    }
    
    func fetch() async throws -> [Post] {
        let dtos = try await localDataSource.loadPosts()
        return dtos.map { $0.toDomain() }
    }
    
    func fetch(for date: Date) async throws -> [Post] {
        let allPosts = try await fetch()
        return allPosts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func delete(_ post: Post) async throws {
        let posts = try await localDataSource.loadPosts()
        let filteredPosts = posts.filter { $0.id != post.id.uuidString }
        try await localDataSource.savePosts(filteredPosts)
    }
    
    func update(_ post: Post) async throws {
        try await save(post)
    }
    
    func clear() async throws {
        try await localDataSource.clearAll()
    }
}

// Data/Repositories/TagRepositoryImpl.swift
class TagRepositoryImpl: TagRepositoryProtocol {
    private let localDataSource: LocalDataSourceProtocol
    
    init(localDataSource: LocalDataSourceProtocol) {
        self.localDataSource = localDataSource
    }
    
    func save(_ tags: [String], category: TagCategory) async throws {
        try await localDataSource.saveTags(tags, category: category)
    }
    
    func fetch(category: TagCategory) async throws -> [String] {
        return try await localDataSource.loadTags(category: category)
    }
    
    func delete(_ tag: String, category: TagCategory) async throws {
        let tags = try await fetch(category: category)
        let filteredTags = tags.filter { $0 != tag }
        try await save(filteredTags, category: category)
    }
    
    func update(old: String, new: String, category: TagCategory) async throws {
        let tags = try await fetch(category: category)
        let updatedTags = tags.map { $0 == old ? new : $0 }
        try await save(updatedTags, category: category)
    }
}
```

## 🎯 Фаза 4: Presentation Layer

### 4.1 ViewModels

```swift
// Presentation/ViewModels/ReportViewModel.swift
@MainActor
class ReportViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var reportStatus: ReportStatus = .notStarted
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let createReportUseCase: CreateReportUseCaseProtocol
    private let getReportsUseCase: GetReportsUseCaseProtocol
    private let updateStatusUseCase: UpdateStatusUseCaseProtocol
    private let sendReportUseCase: SendReportUseCaseProtocol
    
    init(
        createReportUseCase: CreateReportUseCaseProtocol,
        getReportsUseCase: GetReportsUseCaseProtocol,
        updateStatusUseCase: UpdateStatusUseCaseProtocol,
        sendReportUseCase: SendReportUseCaseProtocol
    ) {
        self.createReportUseCase = createReportUseCase
        self.getReportsUseCase = getReportsUseCase
        self.updateStatusUseCase = updateStatusUseCase
        self.sendReportUseCase = sendReportUseCase
    }
    
    func createReport(goodItems: [String], badItems: [String], voiceNotes: [VoiceNote] = []) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let input = CreateReportInput(
                goodItems: goodItems,
                badItems: badItems,
                voiceNotes: voiceNotes,
                type: .regular
            )
            
            let post = try await createReportUseCase.execute(input: input)
            posts.append(post)
            await updateStatus()
            
        } catch {
            handleError(error)
        }
    }
    
    func sendReport(_ post: Post) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let message = formatReportMessage(post)
            let input = SendReportInput(post: post, message: message)
            
            let success = try await sendReportUseCase.execute(input: input)
            
            if success {
                // Обновляем статус отчета в списке
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].published = true
                }
                await updateStatus()
            }
            
        } catch {
            handleError(error)
        }
    }
    
    func loadReports() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            posts = try await getReportsUseCase.execute(input: ())
            await updateStatus()
        } catch {
            handleError(error)
        }
    }
    
    private func updateStatus() async {
        do {
            reportStatus = try await updateStatusUseCase.execute(input: ())
        } catch {
            handleError(error)
        }
    }
    
    private func formatReportMessage(_ post: Post) -> String {
        var message = "📊 Отчет за \(formatDate(post.date))\n\n"
        
        if !post.goodItems.isEmpty {
            message += "✅ Хорошие дела:\n"
            post.goodItems.forEach { message += "• \($0)\n" }
            message += "\n"
        }
        
        if !post.badItems.isEmpty {
            message += "❌ Плохие дела:\n"
            post.badItems.forEach { message += "• \($0)\n" }
        }
        
        return message
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

// Presentation/ViewModels/SettingsViewModel.swift
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var telegramToken: String = ""
    @Published var telegramChatId: String = ""
    @Published var notificationsEnabled: Bool = false
    @Published var notificationMode: NotificationMode = .hourly
    @Published var autoSendEnabled: Bool = false
    @Published var autoSendTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    func loadSettings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let settings = try await settingsRepository.fetch()
            telegramToken = settings.telegramToken
            telegramChatId = settings.telegramChatId
            notificationsEnabled = settings.notificationsEnabled
            notificationMode = settings.notificationMode
            autoSendEnabled = settings.autoSendEnabled
            autoSendTime = settings.autoSendTime
        } catch {
            handleError(error)
        }
    }
    
    func saveSettings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let settings = Settings(
                telegramToken: telegramToken,
                telegramChatId: telegramChatId,
                notificationsEnabled: notificationsEnabled,
                notificationMode: notificationMode,
                autoSendEnabled: autoSendEnabled,
                autoSendTime: autoSendTime
            )
            
            try await settingsRepository.save(settings)
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

### 4.2 Coordinators

```swift
// Presentation/Coordinators/Coordinator.swift
protocol Coordinator: AnyObject {
    func start()
}

protocol CoordinatorDelegate: AnyObject {
    func coordinatorDidFinish(_ coordinator: Coordinator)
}

// Presentation/Coordinators/MainCoordinator.swift
class MainCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let dependencyContainer: DependencyContainer
    weak var delegate: CoordinatorDelegate?
    
    init(navigationController: UINavigationController, dependencyContainer: DependencyContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        let viewModel = dependencyContainer.resolve(ReportViewModel.self)!
        let view = ReportFormView(viewModel: viewModel)
        navigationController.setViewControllers([view], animated: false)
    }
    
    func showReportForm() {
        let viewModel = dependencyContainer.resolve(ReportViewModel.self)!
        let view = ReportFormView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
    
    func showSettings() {
        let viewModel = dependencyContainer.resolve(SettingsViewModel.self)!
        let view = SettingsView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
    
    func showTagManager() {
        let viewModel = dependencyContainer.resolve(TagManagerViewModel.self)!
        let view = TagManagerView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
    
    func showReportsList() {
        let viewModel = dependencyContainer.resolve(ReportsListViewModel.self)!
        let view = ReportsListView(viewModel: viewModel)
        navigationController.pushViewController(view, animated: true)
    }
}
```

## 🎯 Фаза 5: Infrastructure Layer

### 5.1 Services

```swift
// Infrastructure/Services/TelegramService.swift
class TelegramService: RemoteDataSourceProtocol {
    private let apiClient: APIClient
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(apiClient: APIClient, settingsRepository: SettingsRepositoryProtocol) {
        self.apiClient = apiClient
        self.settingsRepository = settingsRepository
    }
    
    func sendMessage(_ message: String) async throws -> Bool {
        let settings = try await settingsRepository.fetch()
        
        guard !settings.telegramToken.isEmpty, !settings.telegramChatId.isEmpty else {
            throw ReportError.telegramError("Не настроен Telegram бот")
        }
        
        let url = URL(string: "https://api.telegram.org/bot\(settings.telegramToken)/sendMessage")!
        let parameters = [
            "chat_id": settings.telegramChatId,
            "text": message,
            "parse_mode": "HTML"
        ]
        
        do {
            let response: TelegramResponse = try await apiClient.post(url: url, parameters: parameters)
            return response.ok
        } catch {
            throw ReportError.telegramError("Ошибка отправки: \(error.localizedDescription)")
        }
    }
    
    func getUpdates() async throws -> [TelegramMessage] {
        let settings = try await settingsRepository.fetch()
        
        guard !settings.telegramToken.isEmpty else {
            throw ReportError.telegramError("Не настроен Telegram бот")
        }
        
        let url = URL(string: "https://api.telegram.org/bot\(settings.telegramToken)/getUpdates")!
        
        do {
            let response: TelegramUpdatesResponse = try await apiClient.get(url: url)
            return response.result
        } catch {
            throw ReportError.telegramError("Ошибка получения обновлений: \(error.localizedDescription)")
        }
    }
    
    func sendVoice(_ voiceData: Data, filename: String) async throws -> Bool {
        let settings = try await settingsRepository.fetch()
        
        guard !settings.telegramToken.isEmpty, !settings.telegramChatId.isEmpty else {
            throw ReportError.telegramError("Не настроен Telegram бот")
        }
        
        let url = URL(string: "https://api.telegram.org/bot\(settings.telegramToken)/sendVoice")!
        
        do {
            let response: TelegramResponse = try await apiClient.uploadVoice(
                url: url,
                voiceData: voiceData,
                filename: filename,
                chatId: settings.telegramChatId
            )
            return response.ok
        } catch {
            throw ReportError.telegramError("Ошибка отправки голосового сообщения: \(error.localizedDescription)")
        }
    }
}

// Infrastructure/Services/NotificationService.swift
class NotificationService {
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    func scheduleNotifications() async throws {
        let settings = try await settingsRepository.fetch()
        
        guard settings.notificationsEnabled else {
            cancelAllNotifications()
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus == .authorized else {
            throw ReportError.validationFailed("Нет разрешения на уведомления")
        }
        
        // Удаляем старые уведомления
        center.removeAllPendingNotificationRequests()
        
        // Создаем новые уведомления
        let notifications = createNotifications(for: settings)
        
        for notification in notifications {
            try await center.add(notification)
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func createNotifications(for settings: Settings) -> [UNNotificationRequest] {
        var notifications: [UNNotificationRequest] = []
        
        switch settings.notificationMode {
        case .hourly:
            // Создаем уведомления каждый час с 8 до 22
            for hour in 8..<22 {
                let content = UNMutableNotificationContent()
                content.title = "LazyBones"
                content.body = "Время заполнить отчет!"
                content.sound = .default
                
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: "report_reminder_\(hour)", content: content, trigger: trigger)
                
                notifications.append(request)
            }
            
        case .twice:
            // Создаем уведомления 2 раза в день
            let times = [(8, 0), (20, 0)]
            
            for (index, (hour, minute)) in times.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "LazyBones"
                content.body = "Время заполнить отчет!"
                content.sound = .default
                
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: "report_reminder_\(index)", content: content, trigger: trigger)
                
                notifications.append(request)
            }
        }
        
        return notifications
    }
}
```

### 5.2 DI контейнер

```swift
// Infrastructure/DI/DependencyContainer.swift
extension DependencyContainer {
    func configure() {
        // Infrastructure layer
        register(APIClient.self) { container in
            return APIClient()
        }
        
        register(TimeProviderProtocol.self) { container in
            return TimeProvider()
        }
        
        // Data layer
        register(LocalDataSourceProtocol.self) { container in
            return LocalDataSourceImpl()
        }
        
        register(RemoteDataSourceProtocol.self) { container in
            let apiClient = container.resolve(APIClient.self)!
            let settingsRepository = container.resolve(SettingsRepositoryProtocol.self)!
            return TelegramService(apiClient: apiClient, settingsRepository: settingsRepository)
        }
        
        register(PostRepositoryProtocol.self) { container in
            let localDataSource = container.resolve(LocalDataSourceProtocol.self)!
            let remoteDataSource = container.resolve(RemoteDataSourceProtocol.self)!
            return PostRepositoryImpl(localDataSource: localDataSource, remoteDataSource: remoteDataSource)
        }
        
        register(TagRepositoryProtocol.self) { container in
            let localDataSource = container.resolve(LocalDataSourceProtocol.self)!
            return TagRepositoryImpl(localDataSource: localDataSource)
        }
        
        register(SettingsRepositoryProtocol.self) { container in
            let localDataSource = container.resolve(LocalDataSourceProtocol.self)!
            return SettingsRepositoryImpl(localDataSource: localDataSource)
        }
        
        // Domain layer
        register(CreateReportUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            return CreateReportUseCase(repository: repository)
        }
        
        register(GetReportsUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            return GetReportsUseCase(repository: repository)
        }
        
        register(UpdateStatusUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            let timeProvider = container.resolve(TimeProviderProtocol.self)!
            return UpdateStatusUseCase(repository: repository, timeProvider: timeProvider)
        }
        
        register(SendReportUseCaseProtocol.self) { container in
            let repository = container.resolve(PostRepositoryProtocol.self)!
            let telegramService = container.resolve(RemoteDataSourceProtocol.self)!
            return SendReportUseCase(repository: repository, telegramService: telegramService)
        }
        
        // Presentation layer
        register(ReportViewModel.self) { container in
            let createUseCase = container.resolve(CreateReportUseCaseProtocol.self)!
            let getUseCase = container.resolve(GetReportsUseCaseProtocol.self)!
            let updateUseCase = container.resolve(UpdateStatusUseCaseProtocol.self)!
            let sendUseCase = container.resolve(SendReportUseCaseProtocol.self)!
            
            return ReportViewModel(
                createReportUseCase: createUseCase,
                getReportsUseCase: getUseCase,
                updateStatusUseCase: updateUseCase,
                sendReportUseCase: sendUseCase
            )
        }
        
        register(SettingsViewModel.self) { container in
            let settingsRepository = container.resolve(SettingsRepositoryProtocol.self)!
            return SettingsViewModel(settingsRepository: settingsRepository)
        }
        
        register(NotificationService.self) { container in
            let settingsRepository = container.resolve(SettingsRepositoryProtocol.self)!
            return NotificationService(settingsRepository: settingsRepository)
        }
    }
}
```

---

*Примеры кода созданы: 3 августа 2025*
*Последнее обновление: 3 августа 2025* 