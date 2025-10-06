# Безопасность проекта

## 🔒 Что НЕ публиковать в Git

### ❌ Никогда не коммитьте:
- Реальные Telegram Bot токены
- API ключи от внешних сервисов
- Пароли и секретные ключи
- Provisioning Profiles (.mobileprovision)
- Сертификаты разработчика (.p12, .cer)
- Файлы с реальными настройками пользователей

### ✅ Безопасно публиковать:
- Development Team ID (H2GFBK2X44)
- Bundle Identifiers (com.katapios.LazyBones)
- App Group Identifiers
- Тестовые токены и ключи (test_token, tok, bad)

## 🛡️ Рекомендации

### 1. Используйте переменные окружения
```swift
// Хорошо
let token = ProcessInfo.processInfo.environment["TELEGRAM_TOKEN"] ?? ""

// Плохо
let token = "1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
```

### 2. Храните секреты в Keychain
```swift
// Используйте Keychain для хранения токенов
KeychainHelper.save(token, forKey: "telegram_token")
```

### 3. Используйте конфигурационные файлы
- Создайте `Config.example.plist` с примерами
- Добавьте `Config.plist` в .gitignore
- Документируйте необходимые настройки

### 4. Проверяйте перед коммитом
```bash
# Проверьте, что нет секретов в коде
grep -r "password\|secret\|token\|key" --include="*.swift" .
```

## 📱 Настройка для разработки

### 1. Создайте Config.plist (не коммитьте!)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>TelegramBotToken</key>
    <string>YOUR_REAL_TOKEN_HERE</string>
    <key>TelegramChatId</key>
    <string>YOUR_CHAT_ID_HERE</string>
</dict>
</plist>
```

### 2. Добавьте в .gitignore
```
Config.plist
secrets.plist
*.mobileprovision
*.p12
*.cer
```

## 🚨 Если случайно закоммитили секрет

1. **Немедленно** отзовите токен/ключ в сервисе
2. Удалите из истории Git:
```bash
git filter-branch --force --index-filter \
'git rm --cached --ignore-unmatch path/to/secret/file' \
--prune-empty --tag-name-filter cat -- --all
```
3. Принудительно отправьте изменения:
```bash
git push origin --force --all
```

## 📞 Контакты
При обнаружении утечки секретов немедленно свяжитесь с командой разработки.
