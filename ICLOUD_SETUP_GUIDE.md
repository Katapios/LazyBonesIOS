# 🍎 Настройка iCloud для LazyBones

## 📋 Что нужно сделать в Xcode

### 1. **Включить iCloud Capability**
1. Откройте проект в Xcode
2. Выберите target `LazyBones`
3. Перейдите в `Signing & Capabilities`
4. Нажмите `+ Capability`
5. Добавьте `iCloud`

### 2. **Настроить iCloud Container**
1. В разделе `iCloud` включите `CloudKit`
2. Добавьте контейнер: `iCloud.com.katapios.LazyBones`
3. Включите `Cloud Documents`

### 3. **Проверить Entitlements**
Файл `LazyBones.entitlements` должен содержать:
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.katapios.LazyBones</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
</array>
```

## 📱 Что нужно сделать на устройстве

### 1. **Войти в iCloud**
- Настройки → Apple ID → iCloud
- Убедитесь, что вы вошли в iCloud аккаунт

### 2. **Включить iCloud Drive**
- Настройки → Apple ID → iCloud → iCloud Drive
- Включите iCloud Drive

### 3. **Разрешить доступ к iCloud**
- Настройки → Apple ID → iCloud → Управление хранилищем
- Убедитесь, что приложение имеет доступ к iCloud

## 🔍 Диагностика

### Проверка в коде
Система проверяет два условия:
1. `FileManager.default.ubiquityIdentityToken != nil` - есть ли активный iCloud аккаунт
2. `FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil` - может ли приложение получить доступ к iCloud контейнеру

### Логи
В консоли Xcode будут видны сообщения:
- `"iCloud check - hasToken: true, canAccessICloud: true"` - все работает
- `"No ubiquityIdentityToken"` - пользователь не вошел в iCloud
- `"Cannot get iCloud URL"` - проблема с entitlements или контейнером

## 📁 Где будет файл

После настройки файл будет находиться в:
```
~/Library/Mobile Documents/com~apple~CloudDocs/Documents/LazyBonesReports/LazyBonesReports.report
```

Это папка iCloud Drive, доступная всем пользователям с доступом к папке `LazyBonesReports`. 