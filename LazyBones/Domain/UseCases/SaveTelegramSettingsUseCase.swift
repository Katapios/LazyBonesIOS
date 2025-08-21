import Foundation

public protocol SaveTelegramSettingsUseCase {
    func execute(_ settings: TelegramSettings)
}
