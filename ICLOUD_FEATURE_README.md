# 📱 iCloud Reports Feature - Документация

## 🎯 Обзор

Новая функциональность **iCloud Reports** позволяет пользователям экспортировать и импортировать отчеты через iCloud Drive, создавая систему совместных отчетов между устройствами.

## 🏗️ Архитектура

### Clean Architecture Implementation

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  ICloudReportsViewModel ✅                                  │
│  ICloudReportsView ✅                                       │
│  SettingsView Integration ✅                                │
│  ReportsView Integration ✅                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  DomainICloudReport ✅                                      │
│  ExportReportsUseCase ✅                                    │
│  ImportICloudReportsUseCase ✅                              │
│  ICloudReportRepositoryProtocol ✅                          │
│  ReportFormatterProtocol ✅                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  ICloudReportRepository ✅                                  │
│  ICloudFileManager ✅                                       │
│  ReportFormatter ✅                                         │
│  ICloudReportMapper ✅                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                    │
├─────────────────────────────────────────────────────────────┤
│  ICloudService ✅                                           │
│  DependencyContainer Integration ✅                         │
│  iCloud Drive Integration ✅                                │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Функциональность

### 1. Экспорт отчетов в iCloud

**Локация**: Настройки → iCloud экспорт

**Функции**:
- ✅ Экспорт отчетов за сегодня в формате Telegram
- ✅ Автоматическое создание папки `LazyBonesReports` в iCloud Drive
- ✅ Сохранение в файл `LazyBonesReports.report`
- ✅ Дополнение к существующему файлу (не перезапись)
- ✅ Включение информации об устройстве

**Обработка ошибок**:
- ⚠️ Нет отчетов за сегодня → "Нет отчетов за сегодня для экспорта"
- ❌ iCloud недоступен → "iCloud недоступен"
- ❌ Нет доступа к файлу → "Нет доступа к файлу"

### 2. Импорт отчетов из iCloud

**Локация**: Отчеты → Отчеты из iCloud

**Функции**:
- ✅ Загрузка отчетов за сегодня из iCloud файла
- ✅ Отображение информации о файле (размер, время обновления)
- ✅ Кнопка "Обновить" для перезагрузки
- ✅ Кнопка "Удалить файл" для очистки
- ✅ Отображение отчетов всех пользователей

**Состояния**:
- 🔄 Загрузка → ProgressView с текстом
- ❌ Ошибка → Кнопка "Повторить" с описанием ошибки
- 📭 Пусто → "Нет отчетов за сегодня" с инструкциями
- ✅ Успех → Список отчетов с карточками

## 📁 Структура файлов

### Domain Layer
```
LazyBones/Domain/Entities/DomainICloudReport.swift
LazyBones/Domain/UseCases/ExportReportsUseCase.swift
LazyBones/Domain/UseCases/ImportICloudReportsUseCase.swift
LazyBones/Domain/Repositories/ICloudReportRepositoryProtocol.swift
LazyBones/Domain/Repositories/ReportFormatterProtocol.swift
```

### Data Layer
```
LazyBones/Data/DataSources/ICloudFileManager.swift
LazyBones/Data/DataSources/ReportFormatter.swift
LazyBones/Data/Repositories/ICloudReportRepository.swift
LazyBones/Data/Mappers/ICloudReportMapper.swift
```

### Infrastructure Layer
```
LazyBones/Core/Services/ICloudService.swift
```

### Presentation Layer
```
LazyBones/Presentation/ViewModels/ICloudReportsViewModel.swift
LazyBones/Presentation/Views/ICloudReportsView.swift
```

### Tests
```
Tests/ArchitectureTests/ICloudServiceTests.swift
Tests/Presentation/ViewModels/ICloudReportsViewModelTests.swift
Tests/Integration/ICloudIntegrationTests.swift
```

## 🔧 Конфигурация

### iCloud Drive
- **Папка**: `LazyBonesReports/`
- **Файл**: `LazyBonesReports.report`
- **Формат**: Текстовый файл с Telegram-разметкой

### Dependency Injection
Все сервисы зарегистрированы в `DependencyContainer`:
- `ICloudFileManager`
- `ReportFormatter`
- `ICloudReportRepository`
- `ExportReportsUseCase`
- `ImportICloudReportsUseCase`
- `ICloudService`

## 📊 Форматы данных

### DomainICloudReport
```swift
struct DomainICloudReport {
    let id: UUID
    let date: Date
    let deviceName: String
    let deviceIdentifier: String
    let username: String?
    let reportContent: String
    let reportType: PostType
    let timestamp: Date
}
```

### Форматы экспорта
- **Telegram**: HTML-разметка с эмодзи
- **Plain**: Простой текст
- **JSON**: Структурированные данные

## 🧪 Тестирование

### Unit Tests
- ✅ `ICloudServiceTests` - тестирование сервиса
- ✅ `ICloudReportsViewModelTests` - тестирование ViewModel

### Integration Tests
- ✅ `ICloudIntegrationTests` - полный цикл экспорт/импорт
- ✅ Тестирование с пустыми отчетами
- ✅ Тестирование недоступности iCloud

### Mock Objects
- ✅ `MockICloudService`
- ✅ `MockICloudFileManager`
- ✅ `MockReportFormatter`
- ✅ `MockICloudReportRepository`

## 🔄 Пользовательские сценарии

### Сценарий 1: Экспорт отчетов
1. Пользователь создает отчеты за сегодня
2. Переходит в Настройки → iCloud экспорт
3. Нажимает "Экспортировать отчеты в iCloud"
4. Система проверяет наличие отчетов за сегодня
5. Если отчеты есть → экспортирует в iCloud
6. Если отчетов нет → показывает предупреждение

### Сценарий 2: Импорт отчетов
1. Пользователь переходит в Отчеты → Отчеты из iCloud
2. Система проверяет доступность iCloud
3. Загружает отчеты за сегодня из файла
4. Отображает список отчетов всех пользователей
5. Показывает информацию о файле

### Сценарий 3: Пустые отчеты
1. Пользователь пытается экспортировать без отчетов
2. Система показывает: "⚠️ Нет отчетов за сегодня для экспорта"
3. Пользователь создает отчеты и повторяет экспорт

## 🐛 Обработка ошибок

### ExportReportsError
- `noReportsToExport` - нет отчетов для экспорта
- `iCloudNotAvailable` - iCloud недоступен
- `fileAccessDenied` - нет доступа к файлу
- `formattingError` - ошибка форматирования

### ImportICloudReportsError
- `iCloudNotAvailable` - iCloud недоступен
- `fileNotFound` - файл не найден
- `noReportsFound` - отчеты не найдены
- `parsingError` - ошибка чтения файла

## 📈 Метрики

### Логирование
- ✅ Экспорт отчетов (количество, успех/ошибка)
- ✅ Импорт отчетов (количество, успех/ошибка)
- ✅ Доступность iCloud
- ✅ Операции с файлами

### Аналитика
- Количество экспортов в день
- Количество импортов в день
- Размер файла отчетов
- Количество устройств в системе

## 🔮 Будущие улучшения

### Краткосрочные
- [ ] Экспорт за выбранный период
- [ ] Фильтрация по устройствам
- [ ] Уведомления о новых отчетах
- [ ] Автоматическая синхронизация

### Долгосрочные
- [ ] Веб-интерфейс для просмотра отчетов
- [ ] Статистика и аналитика
- [ ] Командные отчеты
- [ ] Интеграция с календарем

## 📝 Примечания

### Совместимость
- ✅ Обратная совместимость с существующими отчетами
- ✅ Интеграция с существующим UI
- ✅ Использование существующих моделей данных

### Производительность
- ✅ Асинхронные операции
- ✅ Кэширование данных
- ✅ Оптимизированное чтение файлов

### Безопасность
- ✅ Проверка доступности iCloud
- ✅ Обработка ошибок доступа
- ✅ Валидация данных

---

**Статус**: ✅ Завершено и протестировано  
**Версия**: 1.0.0  
**Дата**: 2025-01-XX 