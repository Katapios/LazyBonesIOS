# Обновление конфигурации без хардкода

## Проблема
Ранее в проекте использовался хардкод для app group и других конфигурационных значений в разных местах:
- `LazyBones.entitlements`
- `LazyBonesWidgetExtension.entitlements`
- `Info.plist`
- `project.pbxproj`

## Решение
Теперь все конфигурационные значения централизованы в `AppConfig.swift` и автоматически синхронизируются через Build Settings переменные.

## Как это работает

### 1. Центральная конфигурация
Все константы определены в `LazyBones/Core/Common/Utils/AppConfig.swift`:
```swift
static let appGroup = "group.com.H2GFBK2X44.loopkit.LoopGroup"
static let backgroundTaskIdentifier = "com.katapios.LazyBones.sendReport"
static let mainBundleId = "com.katapios.LazyBones"
static let widgetBundleId = "com.katapios.LazyBones.LazyBonesWidget"
```

### 2. Build Settings переменные
В `project.pbxproj` добавлена переменная:
```
APP_GROUP_IDENTIFIER = "group.com.H2GFBK2X44.loopkit.LoopGroup"
```

### 3. Entitlements файлы
Теперь используют переменную вместо хардкода:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>$(APP_GROUP_IDENTIFIER)</string>
</array>
```

### 4. Автоматическая синхронизация
Скрипт `update_config.sh` автоматически синхронизирует все файлы с `AppConfig.swift`.

## Как изменить конфигурацию

### Вариант 1: Ручное изменение
1. Отредактируйте `LazyBones/Core/Common/Utils/AppConfig.swift`
2. Запустите скрипт: `./update_config.sh`
3. Пересоберите проект

### Вариант 2: Прямое изменение Build Settings
1. Откройте проект в Xcode
2. Выберите проект в навигаторе
3. Перейдите в Build Settings
4. Найдите `APP_GROUP_IDENTIFIER`
5. Измените значение
6. Пересоберите проект

## Проверка конфигурации
Запустите тест конфигурации:
```swift
ConfigTest.testAllConfigVariables()
```

## Файлы, которые обновляются автоматически
- `LazyBones.xcodeproj/project.pbxproj` - Build Settings
- `LazyBones/Info.plist` - Background Task Identifier
- `LazyBonesWidget/WidgetConfig.swift` - Синхронизация с AppConfig

## Особенности WidgetConfig.swift
`WidgetConfig.swift` содержит дублированные константы из `AppConfig.swift` для виджета. Это необходимо, потому что:
- Виджет не может импортировать файлы из основного приложения
- Нужно обеспечить синхронизацию констант между приложением и виджетом
- Скрипт `update_config.sh` автоматически синхронизирует эти значения

## Файлы, которые используют переменные
- `LazyBones/LazyBones.entitlements` - `$(APP_GROUP_IDENTIFIER)`
- `LazyBonesWidgetExtension.entitlements` - `$(APP_GROUP_IDENTIFIER)`

## Преимущества
✅ Нет хардкода в конфигурационных файлах  
✅ Централизованное управление конфигурацией  
✅ Автоматическая синхронизация  
✅ Легкое изменение конфигурации  
✅ Меньше ошибок при изменении bundle ID или app group  

## Важные замечания
- После изменения app group в Apple Developer Console нужно обновить provisioning profiles
- Убедитесь, что app group существует в Apple Developer Console
- Все targets (основное приложение и виджет) должны использовать одинаковый app group
