#!/bin/bash

# Скрипт для обновления конфигурации из AppConfig.swift
# Этот скрипт автоматически обновляет все места, где используются конфигурационные константы

echo "🔄 Обновление конфигурации из AppConfig.swift..."

# Извлекаем значения из AppConfig.swift
APP_GROUP=$(grep 'static let appGroup = ' LazyBones/Core/Common/Utils/AppConfig.swift | sed 's/.*"\(.*\)".*/\1/')
BACKGROUND_TASK_ID=$(grep 'static let backgroundTaskIdentifier = ' LazyBones/Core/Common/Utils/AppConfig.swift | sed 's/.*"\(.*\)".*/\1/')
MAIN_BUNDLE_ID=$(grep 'static let mainBundleId = ' LazyBones/Core/Common/Utils/AppConfig.swift | sed 's/.*"\(.*\)".*/\1/')
WIDGET_BUNDLE_ID=$(grep 'static let widgetBundleId = ' LazyBones/Core/Common/Utils/AppConfig.swift | sed 's/.*"\(.*\)".*/\1/')

echo "📦 Main Bundle ID: $MAIN_BUNDLE_ID"
echo "📦 Widget Bundle ID: $WIDGET_BUNDLE_ID"
echo "👥 App Group: $APP_GROUP"
echo "🔄 Background Task ID: $BACKGROUND_TASK_ID"

# Обновляем project.pbxproj
echo "🔧 Обновление project.pbxproj..."
sed -i '' "s/APP_GROUP_IDENTIFIER = \".*\"/APP_GROUP_IDENTIFIER = \"$APP_GROUP\"/g" LazyBones.xcodeproj/project.pbxproj

# Обновляем Info.plist
echo "📄 Обновление Info.plist..."
sed -i '' "s/<string>com\.katapios\.LazyBones.*\.sendReport<\/string>/<string>$BACKGROUND_TASK_ID<\/string>/g" LazyBones/Info.plist

# Обновляем WidgetConfig.swift (синхронизируем с AppConfig.swift)
echo "📱 Синхронизация WidgetConfig.swift с AppConfig.swift..."
sed -i '' "s/static let appGroup = \".*\"/static let appGroup = \"$APP_GROUP\"/g" LazyBonesWidget/WidgetConfig.swift

# Синхронизируем widget identifiers
WIDGET_KIND=$(grep 'static let widgetKind = ' LazyBones/Core/Common/Utils/AppConfig.swift | sed 's/.*"\(.*\)".*/\1/')
sed -i '' "s/static let primaryWidgetKind = \".*\"/static let primaryWidgetKind = \"$WIDGET_KIND\"/g" LazyBonesWidget/WidgetConfig.swift
sed -i '' "s/static let widgetKind = primaryWidgetKind/static let widgetKind = primaryWidgetKind/g" LazyBonesWidget/WidgetConfig.swift

echo "✅ Конфигурация обновлена!"
echo ""
echo "📋 Сводка изменений:"
echo "   - App Group: $APP_GROUP"
echo "   - Background Task: $BACKGROUND_TASK_ID"
echo "   - Main Bundle: $MAIN_BUNDLE_ID"
echo "   - Widget Bundle: $WIDGET_BUNDLE_ID"
echo ""
echo "💡 Теперь все конфигурационные значения берутся из AppConfig.swift"
echo "   Для изменения конфигурации просто отредактируйте AppConfig.swift и запустите этот скрипт"
