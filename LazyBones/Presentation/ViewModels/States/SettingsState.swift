import Foundation

/// Состояние экрана настроек
struct SettingsState {
    // MARK: - Device
    var deviceName: String = ""
    var showSaved: Bool = false

    // MARK: - Telegram
    var telegramToken: String = ""
    var telegramChatId: String = ""
    var telegramBotId: String = ""
    var telegramStatus: String? = nil

    // MARK: - Background Fetch Test
    var isBackgroundFetchTestEnabled: Bool = false

    // MARK: - iCloud
    var isICloudAvailable: Bool = false
    var isExportingToICloud: Bool = false
    var exportResult: String? = nil

    // MARK: - AutoSend
    var autoSendEnabled: Bool = false
    var autoSendTime: Date = Date()
    var lastAutoSendStatus: String? = nil
}