# 🍎 Apple Watch App для LazyBones

## Обзор

Apple Watch приложение для LazyBones предоставляет быстрый доступ к статусу отчетов, таймеру и возможность добавлять пункты отчетов прямо с часов.

## Функциональность

### ✅ Реализовано

1. **Главный экран Watch App**
   - Отображение статуса дня (не начат/в процессе/отправлен)
   - Таймер с круговым прогрессом "До конца"
   - Мотивационные лозунги (обновляются каждые 15 минут)
   - Статистика: количество пунктов "Хорошее" и "Плохое"

2. **Быстрые действия**
   - Добавить хорошее (голосовой/текстовый ввод)
   - Добавить плохое (голосовой/текстовый ввод)
   - Просмотр плана на день

3. **Компликации для циферблата**
   - Circular: статус с прогрессом
   - Rectangular: статус, таймер и лозунг
   - Inline: краткий статус
   - Corner: компактный статус

4. **Синхронизация данных**
   - WatchConnectivity для передачи данных между iPhone и Watch
   - App Group UserDefaults для общих данных
   - Автоматическое обновление при изменении статуса или таймера

## Архитектура

### Структура файлов

```
LazyBonesWatch/
├── LazyBonesWatchApp.swift          # Точка входа Watch App
├── WatchConfig.swift                 # Конфигурация (App Group, Bundle ID)
├── Views/
│   ├── ContentView.swift            # Корневой view
│   ├── MainWatchView.swift          # Главный экран
│   ├── AddReportItemView.swift      # Добавление пункта отчета
│   └── PlanView.swift               # План на день
├── ViewModels/
│   └── WatchMainViewModel.swift     # ViewModel для главного экрана
├── Core/
│   └── Services/
│       └── WatchConnectivityService.swift  # Сервис синхронизации (Watch сторона)
├── Complications/
│   ├── LazyBonesComplication.swift  # Компликации
│   └── LazyBonesComplicationBundle.swift
└── Models/
    └── WatchReportData.swift        # Модель данных для синхронизации
```

### Интеграция с основным приложением

Основное приложение использует `WatchSyncService` для отправки данных на Watch:

```swift
// LazyBones/Core/Services/WatchSyncService.swift
// Автоматически отправляет данные при:
// - Изменении статуса отчета (.reportStatusDidChange)
// - Обновлении таймера (.reportPeriodActivityChanged)
// - Запуске приложения
```

## Настройка в Xcode

### 1. Создание Watch App Target

1. File → New → Target
2. Выберите "watchOS" → "App"
3. Название: `LazyBonesWatch`
4. Bundle Identifier: `com.katapios.LazyBones.watchkitapp`
5. Language: Swift
6. Interface: SwiftUI

### 2. Настройка App Groups

Убедитесь, что все targets (основное приложение, виджет, Watch App) используют один App Group:

- App Group: `group.KP`
- Настроить в: Signing & Capabilities → App Groups

### 3. Настройка WatchConnectivity

1. В основном приложении добавьте capability: "Background Modes" → "Remote notifications"
2. В Watch App добавьте capability: "Background Modes" → "Remote notifications"

### 4. Добавление файлов в Watch Target

Добавьте все файлы из `LazyBonesWatch/` в Watch App target:
- Отметьте "Copy items if needed"
- Выберите правильный target membership

## Использование

### На Watch

1. Откройте LazyBones на часах
2. Просмотрите статус дня и таймер
3. Используйте быстрые действия для добавления пунктов
4. Просмотрите план на день

### Компликации

1. Долгое нажатие на циферблат
2. Нажмите "Настроить"
3. Выберите слот для компликации
4. Найдите "LazyBones" и выберите нужный тип

## Технические детали

### Синхронизация данных

Данные синхронизируются через:
1. **WatchConnectivity** (приоритет) - для реального времени
2. **App Group UserDefaults** (fallback) - для компликаций и офлайн доступа

### Обновление компликаций

Компликации обновляются через `TimelineProvider`:
- Обновление каждые 15 минут
- Timeline на 4 часа вперед
- Автоматическое обновление при изменении данных

### Обработка ошибок

- Если Watch недоступен, данные сохраняются локально
- При восстановлении связи данные синхронизируются автоматически
- Fallback на UserDefaults для офлайн работы

## Best Practices

1. **Минимизация передачи данных**
   - Отправляем только необходимые данные
   - Используем сжатие для больших данных

2. **Энергоэффективность**
   - Обновления не чаще чем раз в 30 секунд
   - Используем background updates только при необходимости

3. **UX на маленьком экране**
   - Короткие тексты
   - Крупные кнопки
   - Минимум навигации

4. **Обратная совместимость**
   - Graceful degradation при отсутствии Watch
   - Работа без WatchConnectivity через UserDefaults

## Будущие улучшения

- [ ] Полноценный голосовой ввод через Speech framework
- [ ] Тактильные уведомления при напоминаниях
- [ ] Интеграция с HealthKit
- [ ] Быстрая отправка отчетов с Watch
- [ ] Voice Notes запись прямо с Watch

## Отладка

### Проверка синхронизации

1. Убедитесь, что оба устройства в одной сети Wi-Fi
2. Проверьте, что Watch App установлен и запущен
3. Проверьте логи в Xcode Console:
   - `[WatchSync]` - синхронизация с iPhone
   - `[Watch]` - работа Watch App

### Проблемы

**Watch не получает данные:**
- Проверьте App Groups в Capabilities
- Убедитесь, что WatchConnectivity активирован
- Проверьте, что Watch App запущен

**Компликации не обновляются:**
- Проверьте Timeline Provider
- Убедитесь, что данные сохраняются в UserDefaults
- Перезагрузите Watch

## Лицензия

См. основной README проекта.

