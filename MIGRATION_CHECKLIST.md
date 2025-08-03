# ✅ Чек-лист миграции к Clean Architecture

## 🚀 Быстрый старт

### Шаг 1: Подготовка (1-2 дня)
- [ ] Создать ветку `feature/clean-architecture-migration`
- [ ] Создать новую структуру папок
- [ ] Скопировать существующие файлы в новые папки
- [ ] Обновить импорты в Xcode

### Шаг 2: Domain Layer (3-5 дней)
- [ ] Создать Domain Entities (Post, VoiceNote, ReportStatus)
- [ ] Создать базовые Use Cases (CreateReport, GetReports, UpdateStatus)
- [ ] Создать Repository интерфейсы
- [ ] Написать unit тесты для Use Cases

### Шаг 3: Data Layer (3-5 дней)
- [ ] Создать Data Models (DTOs)
- [ ] Реализовать Data Sources
- [ ] Реализовать Repository классы
- [ ] Написать unit тесты для репозиториев

### Шаг 4: Presentation Layer (3-5 дней)
- [ ] Создать ViewModels
- [ ] Обновить Views для работы с ViewModels
- [ ] Создать Coordinators
- [ ] Написать unit тесты для ViewModels

### Шаг 5: Infrastructure Layer (2-3 дня)
- [ ] Мигрировать существующие сервисы
- [ ] Обновить DI контейнер
- [ ] Настроить зависимости

### Шаг 6: Тестирование (2-3 дня)
- [ ] Написать integration тесты
- [ ] Протестировать все функции
- [ ] Исправить найденные баги

## 📋 Детальный чек-лист

### Фаза 1: Подготовка
- [ ] Создать структуру папок:
  ```
  mkdir -p LazyBones/Domain/{Entities,UseCases,Repositories}
  mkdir -p LazyBones/Data/{Repositories,DataSources,Models}
  mkdir -p LazyBones/Presentation/{ViewModels,Views,Coordinators}
  mkdir -p LazyBones/Infrastructure/{Services,Persistence,DI}
  ```
- [ ] Создать базовые протоколы (UseCaseProtocol, RepositoryProtocol)
- [ ] Обновить DependencyContainer
- [ ] Создать карту миграции компонентов

### Фаза 2: Domain Layer
- [ ] **Entities:**
  - [ ] Post.swift (перенести из Models/)
  - [ ] VoiceNote.swift (перенести из Models/)
  - [ ] ReportStatus.swift (создать enum)
  - [ ] PostType.swift (создать enum)
  - [ ] TagCategory.swift (создать enum)
- [ ] **Use Cases:**
  - [ ] CreateReportUseCase.swift
  - [ ] GetReportsUseCase.swift
  - [ ] UpdateStatusUseCase.swift
  - [ ] SendReportUseCase.swift
- [ ] **Repository Interfaces:**
  - [ ] PostRepositoryProtocol.swift
  - [ ] TagRepositoryProtocol.swift
  - [ ] SettingsRepositoryProtocol.swift

### Фаза 3: Data Layer
- [ ] **Data Models:**
  - [ ] PostDTO.swift
  - [ ] VoiceNoteDTO.swift
  - [ ] TelegramMessage.swift
- [ ] **Data Sources:**
  - [ ] LocalDataSourceProtocol.swift
  - [ ] LocalDataSourceImpl.swift
  - [ ] RemoteDataSourceProtocol.swift
- [ ] **Repository Implementations:**
  - [ ] PostRepositoryImpl.swift
  - [ ] TagRepositoryImpl.swift
  - [ ] SettingsRepositoryImpl.swift

### Фаза 4: Presentation Layer
- [ ] **ViewModels:**
  - [ ] ReportViewModel.swift
  - [ ] SettingsViewModel.swift
  - [ ] TagManagerViewModel.swift
  - [ ] ReportsListViewModel.swift
- [ ] **Coordinators:**
  - [ ] Coordinator.swift (протокол)
  - [ ] MainCoordinator.swift
- [ ] **Views (обновить существующие):**
  - [ ] ReportFormView.swift
  - [ ] SettingsView.swift
  - [ ] TagManagerView.swift
  - [ ] ReportsListView.swift

### Фаза 5: Infrastructure Layer
- [ ] **Services:**
  - [ ] TelegramService.swift (обновить)
  - [ ] NotificationService.swift (обновить)
  - [ ] BackgroundTaskService.swift (обновить)
- [ ] **DI:**
  - [ ] DependencyContainer.swift (обновить configure())
- [ ] **Persistence:**
  - [ ] UserDefaultsManager.swift (обновить)

### Фаза 6: Тестирование
- [ ] **Unit Tests:**
  - [ ] CreateReportUseCaseTests.swift
  - [ ] PostRepositoryImplTests.swift
  - [ ] ReportViewModelTests.swift
- [ ] **Integration Tests:**
  - [ ] ReportFlowTests.swift
- [ ] **UI Tests:**
  - [ ] ReportFormUITests.swift

## 🎯 Приоритеты миграции

### 🔴 Критично (начать с этого)
1. **Domain Entities** - основа архитектуры
2. **CreateReportUseCase** - основной функционал
3. **PostRepository** - работа с данными
4. **ReportViewModel** - UI логика

### 🟡 Важно (второй этап)
1. **Остальные Use Cases**
2. **Settings и Tag функционал**
3. **Telegram интеграция**
4. **Уведомления**

### 🟢 Желательно (третий этап)
1. **Coordinators**
2. **Background tasks**
3. **Widget интеграция**
4. **Дополнительные тесты**

## ⚠️ Риски и решения

### Риск: Нарушение функциональности
**Решение:** Мигрировать по одному компоненту, тестировать после каждого

### Риск: Долгая миграция
**Решение:** Начать с критичных компонентов, остальное делать постепенно

### Риск: Сложность отладки
**Решение:** Писать тесты параллельно с миграцией

## 📊 Метрики прогресса

- [ ] **0%** - Начало
- [ ] **25%** - Domain Layer готов
- [ ] **50%** - Data Layer готов
- [ ] **75%** - Presentation Layer готов
- [ ] **90%** - Infrastructure Layer готов
- [ ] **100%** - Тестирование завершено

## 🎯 Следующие действия

1. **Сегодня:** Создать ветку и структуру папок
2. **Завтра:** Начать с Domain Entities
3. **На этой неделе:** Завершить Domain Layer
4. **На следующей неделе:** Data Layer
5. **Через 2 недели:** Presentation Layer
6. **Через 3 недели:** Infrastructure Layer
7. **Через 4 недели:** Тестирование и финальная проверка

---

*Чек-лист создан: 3 августа 2025*
*Обновлять по мере выполнения* 