import Foundation

/// Тестовый файл для проверки доступности конфигурационных переменных
struct ConfigTest {
    
    /// Проверяет доступность всех конфигурационных переменных
    static func testAllConfigVariables() {
        print("=== ТЕСТ КОНФИГУРАЦИОННЫХ ПЕРЕМЕННЫХ ===")
        
        // Проверяем Bundle Identifiers
        print("📦 Main Bundle ID: \(AppConfig.mainBundleId)")
        print("📦 Widget Bundle ID: \(AppConfig.widgetBundleId)")
        
        // Проверяем App Groups
        print("👥 App Group: \(AppConfig.appGroup)")
        
        // Проверяем Background Task Identifiers
        print("🔄 Background Task ID: \(AppConfig.backgroundTaskIdentifier)")
        
        // Проверяем Widget Identifiers
        print("📱 Widget Kind: \(AppConfig.widgetKind)")
        
        // Проверяем UserDefaults
        let userDefaults = AppConfig.sharedUserDefaults
        print("💾 UserDefaults Suite: \(AppConfig.appGroup)")
        
        // Тестируем запись и чтение данных
        let testKey = "configTestKey"
        let testValue = "testValue_\(Date().timeIntervalSince1970)"
        
        userDefaults.set(testValue, forKey: testKey)
        let readValue = userDefaults.string(forKey: testKey)
        
        print("✅ UserDefaults Test: \(readValue == testValue ? "PASSED" : "FAILED")")
        print("   Written: \(testValue)")
        print("   Read: \(readValue ?? "nil")")
        
        // Очищаем тестовые данные
        userDefaults.removeObject(forKey: testKey)
        
        print("=== ТЕСТ ЗАВЕРШЕН ===")
    }
    
    /// Проверяет соответствие конфигурации между основным приложением и виджетом
    static func testWidgetConfigCompatibility() {
        print("=== ТЕСТ СОВМЕСТИМОСТИ С ВИДЖЕТОМ ===")
        
        // В реальном приложении мы не можем импортировать WidgetConfig из основного приложения
        // Но мы можем проверить, что наши константы корректны
        print("📱 Widget Kind в AppConfig: \(AppConfig.widgetKind)")
        print("👥 App Group в AppConfig: \(AppConfig.appGroup)")
        
        // Проверяем, что widget kind соответствует ожидаемому формату
        let expectedWidgetKind = "\(AppConfig.mainBundleId).LazyBonesWidget"
        print("🔍 Ожидаемый Widget Kind: \(expectedWidgetKind)")
        print("✅ Widget Kind формат: \(AppConfig.widgetKind == expectedWidgetKind ? "CORRECT" : "INCORRECT")")
        
        print("=== ТЕСТ СОВМЕСТИМОСТИ ЗАВЕРШЕН ===")
    }
} 