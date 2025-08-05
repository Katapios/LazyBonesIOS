# 🔧 Решение проблемы с iCloud Capability

## ❌ Проблема: iCloud capability не добавляется

### Возможные причины:

1. **Проблемы с Apple Developer Account**
2. **Конфликт с существующими capabilities**
3. **Проблемы с Bundle Identifier**
4. **Ограничения в бесплатном аккаунте**

## 🛠️ Решения

### Решение 1: Ручное добавление через project.pbxproj

1. **Откройте файл `LazyBones.xcodeproj/project.pbxproj` в текстовом редакторе**

2. **Найдите секцию с вашим target (обычно `LazyBones`)**

3. **Добавьте следующие строки в секцию target:**

```objc
/* Begin XCBuildConfiguration section */
		// ... existing configuration ...
		buildSettings = {
			// ... existing settings ...
			CODE_SIGN_ENTITLEMENTS = LazyBones/LazyBones.entitlements;
			CODE_SIGN_STYLE = Automatic;
			DEVELOPMENT_TEAM = YOUR_TEAM_ID; // Замените на ваш Team ID
			// ... other settings ...
		};
		name = Debug;
	};
```

4. **Добавьте секцию capabilities:**

```objc
/* Begin XCBuildConfiguration section */
		// ... existing configuration ...
		systemCapabilities = {
			com.apple.iCloud = {
				enabled = 1;
			};
		};
		name = Debug;
	};
```

### Решение 2: Альтернативный способ через entitlements

Если capability не добавляется, можно попробовать добавить только необходимые entitlements:

1. **Убедитесь, что в `LazyBones.entitlements` есть:**

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

2. **Добавьте в Info.plist:**

```xml
<key>NSUbiquitousContainerIsDocumentScopePublic</key>
<true/>
<key>NSUbiquitousContainerName</key>
<string>LazyBones</string>
<key>NSUbiquitousContainerSupportedFolderLevels</key>
<string>None</string>
```

### Решение 3: Проверка Apple Developer Account

1. **Убедитесь, что у вас есть платный Apple Developer Account**
2. **Проверьте, что Bundle Identifier уникален**
3. **Убедитесь, что Team ID правильный**

### Решение 4: Использование альтернативного подхода

Если ничего не помогает, можно использовать альтернативный подход:

1. **Использовать FileProvider для доступа к iCloud Drive**
2. **Использовать Document Picker для выбора файлов**
3. **Использовать Share Extension для экспорта**

## 🔍 Диагностика

### Проверьте логи в Xcode:
```
ICloudFileManager: iCloud check - hasToken: true, canAccessICloud: false, canAccessICloudDrive: true
```

### Проверьте entitlements:
```bash
codesign -d --entitlements :- /path/to/your/app
```

## 📞 Если ничего не помогает

1. **Проверьте Apple Developer Forums**
2. **Создайте bug report в Apple Developer**
3. **Попробуйте создать новый проект с iCloud capability**

## ✅ Текущее решение

Мы уже добавили fallback механизм, который:
1. Сначала пытается использовать ubiquity container
2. Если не получается, использует стандартный путь к iCloud Drive
3. Показывает подробную диагностику в логах

Это должно работать даже без официального iCloud capability! 