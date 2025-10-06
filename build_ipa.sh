#!/bin/bash

# Скрипт для сборки IPA файла
# Использование: ./build_ipa.sh [development|adhoc|enterprise]

BUILD_TYPE=${1:-development}
SCHEME="LazyBones"
ARCHIVE_NAME="LazyBones.xcarchive"
EXPORT_PATH="./build"
EXPORT_OPTIONS="ExportOptions.plist"

echo "🚀 Начинаем сборку IPA файла..."
echo "📱 Тип сборки: $BUILD_TYPE"
echo "📦 Схема: $SCHEME"

# Очищаем предыдущие сборки
echo "🧹 Очистка предыдущих сборок..."
rm -rf "$ARCHIVE_NAME"
rm -rf "$EXPORT_PATH"

# Создаем директорию для экспорта
mkdir -p "$EXPORT_PATH"

# Обновляем конфигурацию
echo "⚙️ Обновление конфигурации..."
./update_config.sh

# Сборка архива
echo "🔨 Сборка архива..."
xcodebuild -project LazyBones.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination generic/platform=iOS \
    archive \
    -archivePath "$ARCHIVE_NAME" \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при сборке архива"
    exit 1
fi

# Экспорт IPA
echo "📦 Экспорт IPA файла..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_NAME" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при экспорте IPA"
    exit 1
fi

echo "✅ IPA файл успешно создан!"
echo "📁 Расположение: $EXPORT_PATH/LazyBones.ipa"
echo ""
echo "📋 Информация о сборке:"
echo "   - Тип: $BUILD_TYPE"
echo "   - Схема: $SCHEME"
echo "   - Конфигурация: Release"
echo ""
echo "📱 Для установки на устройство:"
echo "   1. Скопируйте IPA файл на устройство"
echo "   2. Используйте Xcode, Apple Configurator 2 или сторонние инструменты"
echo "   3. Убедитесь, что устройство добавлено в Apple Developer Console"

