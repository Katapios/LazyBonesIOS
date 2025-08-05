# 📱 LazyBones - Приложение для ежедневных отчетов

## 🎯 Обзор продукта

**LazyBones** - это iOS приложение для создания и отправки ежедневных отчетов о продуктивности. Пользователи могут вести учет своих достижений и неудач, планировать задачи и автоматически отправлять отчеты в Telegram.

**🔄 Проект находится в процессе миграции на Clean Architecture с современными практиками разработки.**

## 🏗️ Архитектура приложения

### 🎯 Clean Architecture - В ПРОЦЕССЕ 🔄

Проект находится в **процессе миграции** на **Clean Architecture** с четким разделением на слои:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  Views (SwiftUI)           │  ViewModels (ObservableObject) │
│  ├─ MainView 🔄            │  ├─ ReportListViewModel ✅      │
│  ├─ ReportsView 🔄         │  ├─ RegularReportsViewModel ✅  │
│  ├─ SettingsView 🔄        │  ├─ CustomReportsViewModel ✅   │
│  └─ Forms                 │  ├─ ExternalReportsViewModel ✅ │
│                            │  ├─ MainViewModel 🔄            │
│  ├─ ReportListView ✅      │  ├─ ReportsViewModel 🔄         │
│  └─ Forms                 │  ├─ SettingsViewModel 🔄        │
│     ├─ RegularReportForm  │  └─ TagManagerViewModel 🔄      │
│     └─ DailyPlanningForm  │                                │
│                            │  States & Events               │
│                            │  ├─ ReportListState ✅          │
│                            │  ├─ RegularReportsState ✅      │
│                            │  ├─ CustomReportsState ✅       │
│                            │  ├─ ReportListEvent ✅          │
│                            │  ├─ RegularReportsEvent ✅      │
│                            │  └─ CustomReportsEvent ✅       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Entities                  │  Use Cases                    │
│  ├─ DomainPost ✅          │  ├─ CreateReportUseCase ✅      │
│  ├─ DomainVoiceNote ✅     │  ├─ GetReportsUseCase ✅        │
│  └─ ReportStatus ✅        │  ├─ UpdateStatusUseCase ✅      │
│                            │  ├─ UpdateReportUseCase ✅      │
│                            │  └─ DeleteReportUseCase ✅      │
│  Repository Protocols      │                                │
│  ├─ PostRepositoryProtocol✅│                                │
│  └─ TagRepositoryProtocol ✅│                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  Repositories              │  Data Sources                 │
│  ├─ PostRepository ✅      │  ├─ UserDefaultsPostDataSource✅│
│  └─ TagRepository ✅       │  └─ LocalStorageProtocol ✅     │
│                            │                                │
│  Mappers                   │  Models                       │
│  ├─ PostMapper ✅          │  ├─ Post (Data Model) ✅        │
│  └─ VoiceNoteMapper ✅     │  └─ VoiceNote (Data Model) ✅   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                    │
├─────────────────────────────────────────────────────────────┤
│  Services                  │  External APIs                │
│  ├─ TelegramService ✅     │  ├─ Telegram Bot API ✅        │
│  ├─ NotificationService ✅ │  └─ UserDefaults ✅            │
│  ├─ AutoSendService ✅     │                                │
│  └─ BackgroundTaskService✅│  WidgetKit ✅                  │
└─────────────────────────────────────────────────────────────┘
```

### 🔄 Dependency Flow

```
Presentation → Domain ← Data → Infrastructure
     ↑           ↑        ↑         ↑
     └───────────┴────────┴─────────┘
           Dependency Injection ✅
```

### 📊 Статус миграции по слоям

| Слой | Статус | Готовность | Описание |
|------|--------|------------|----------|
| **Domain** | ✅ Завершен | 100% | Entities, Use Cases, Repository Protocols |
| **Data** | ✅ Завершен | 100% | Repositories, Data Sources, Mappers |
| **Presentation** | 🔄 В процессе | 30% | ViewModels готовы частично, Views в миграции |
| **Infrastructure** | ✅ Завершен | 100% | Services, DI Container, Coordinators |

## 🚨 Критические проблемы архитектуры

### 1. **Двойная архитектура**
```swift
// В одном приложении сосуществуют:
// НОВАЯ архитектура:
ExternalReportsView(viewModel: ExternalReportsViewModel) // ✅ Clean Architecture

// СТАРАЯ архитектура:
MainView(store: PostStore) // ❌ Прямая зависимость от PostStore
```

### 2. **PostStore как глобальное состояние**
```swift
// ContentView.swift - корень проблемы:
@StateObject var store = PostStore() // Создается глобально

// Все Views получают PostStore:
MainView(store: store)
ReportsView(store: store)
SettingsView(store: store)
TagManagerView(store: store)
```

### 3. **ViewModel-адаптеры вместо настоящих ViewModels**
```swift
// Это НЕ Clean Architecture:
class MainViewModel: ObservableObject {
    @Published var store: PostStore // Прямая зависимость от PostStore!
}

class ReportsViewModel: ObservableObject {
    @Published var store: PostStore // Прямая зависимость от PostStore!
}
```

## 📊 Статусная модель приложения

### 🔄 Жизненный цикл отчета

```
┌─────────────────┐
│   НОВЫЙ ДЕНЬ    │
│   (8:00)        │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│  NOT_STARTED    │
│  (Отчет не      │
│   создан)       │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│  IN_PROGRESS    │
│  (Отчет         │
│   заполняется)  │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│     SENT        │
│  (Отчет         │
│   отправлен)    │
└─────────────────┘
```

### 📊 Типы отчетов

#### 1. 📝 Regular Reports (Обычные отчеты)
- **Тип**: `.regular`
- **Структура**: `goodItems` + `badItems`
- **Назначение**: Ежедневные отчеты о достижениях и неудачах
- **ViewModel**: `RegularReportsViewModel` ✅
- **View**: Интегрирован в `ReportsView` 🔄

#### 2. 📋 Custom Reports (Кастомные отчеты)
- **Тип**: `.custom`
- **Структура**: `goodItems` (план) + `evaluationResults` + `isEvaluated`
- **Назначение**: Планирование и оценка выполнения задач
- **ViewModel**: `CustomReportsViewModel` ✅
- **View**: Интегрирован в `ReportsView` 🔄

#### 3. 📨 External Reports (Внешние отчеты)
- **Тип**: `.external`
- **Источник**: Telegram Bot API
- **Структура**: `externalText`, `authorUsername`, `externalMessageId`
- **Назначение**: Отчеты, полученные из Telegram
- **ViewModel**: `ExternalReportsViewModel` ✅
- **View**: `ExternalReportsView` ✅

## 🎯 Следующие шаги миграции

### **ШАГ 1: Создание настоящих ViewModels (КРИТИЧЕСКИЙ ПРИОРИТЕТ)**
- [ ] Создать `MainViewModel` с новой архитектурой (использует Use Cases)
- [ ] Создать `ReportsViewModel` с новой архитектурой (объединяет все типы отчетов)
- [ ] Создать `SettingsViewModel` с новой архитектурой (использует Use Cases)
- [ ] Создать `TagManagerViewModel` с новой архитектурой (использует Use Cases)

### **ШАГ 2: Миграция Views (КРИТИЧЕСКИЙ ПРИОРИТЕТ)**
- [ ] Мигрировать `MainView` на новую архитектуру
- [ ] Мигрировать `ReportsView` на новую архитектуру
- [ ] Мигрировать `SettingsView` на новую архитектуру
- [ ] Мигрировать `TagManagerView` на новую архитектуру

### **ШАГ 3: Удаление PostStore (ВЫСОКИЙ ПРИОРИТЕТ)**
- [ ] Заменить PostStore на Use Cases в основных Views
- [ ] Удалить PostStore и Post модели
- [ ] Обновить ContentView для удаления зависимости от PostStore

## 🧪 Тестирование

### Покрытие тестами
- **Unit Tests**: ~90% ✅
- **Integration Tests**: ~85% ✅
- **Architecture Tests**: 100% ✅

### Ключевые тестовые сценарии
- ✅ Создание и редактирование отчетов
- ✅ Интеграция с Telegram API
- ✅ Автоотправка отчетов
- ✅ Управление уведомлениями
- ✅ Статусная модель и переходы
- ✅ iCloud экспорт/импорт

## 📊 Метрики качества

### До миграции
- **Покрытие тестами**: ~30%
- **Предупреждения компилятора**: ~15
- **Архитектурная готовность**: ~20%
- **Время разработки новых функций**: Высокое

### После миграции (текущее состояние)
- **Покрытие тестами**: ~90% ✅
- **Предупреждения компилятора**: 0 ✅
- **Архитектурная готовность**: 65% 🔄
- **Время разработки новых функций**: Среднее 🔄

## 🚀 Установка и запуск

### Требования
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

### Установка
```bash
git clone https://github.com/your-username/LazyBonesIOS.git
cd LazyBonesIOS
open LazyBones.xcodeproj
```

### Настройка
1. Откройте проект в Xcode
2. Настройте Bundle Identifier
3. Добавьте Telegram Bot Token в настройках приложения
4. Запустите приложение

## 📱 Основные функции

### ✅ Реализовано
- 📝 Создание ежедневных отчетов
- 📋 Планирование и оценка задач
- 📨 Интеграция с Telegram
- 🔔 Автоматические уведомления
- ☁️ iCloud синхронизация
- 📊 Статистика и аналитика
- 🏷️ Управление тегами

### 🔄 В разработке
- 🎯 Завершение миграции на Clean Architecture
- 📱 Улучшение UI/UX
- 🔧 Оптимизация производительности

## 🤝 Вклад в проект

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

Этот проект лицензирован под MIT License - см. файл [LICENSE](LICENSE) для деталей.

## 📞 Контакты

- **Автор**: Денис Рюмин
- **Email**: denis.rumin@example.com
- **Telegram**: @denis_rumin

---

**🔄 Проект находится в активной разработке. Миграция на Clean Architecture: 65% завершено.**
