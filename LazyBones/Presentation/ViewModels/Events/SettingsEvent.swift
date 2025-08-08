import Foundation

/// События экрана настроек
enum SettingsEvent {
    // MARK: - Lifecycle
    case loadSettings

    // MARK: - Device
    case saveDeviceName(String)

    // MARK: - Telegram
    case saveTelegramSettings(token: String?, chatId: String?, botId: String?)
    case checkTelegramConnection

    // MARK: - iCloud
    case exportToICloud
    case createTestFile
    case checkICloudAvailability

    // MARK: - Data
    case clearAllData
    case unlockReports

    // MARK: - Background Fetch Test
    case setBackgroundFetchTestEnabled(Bool)
}