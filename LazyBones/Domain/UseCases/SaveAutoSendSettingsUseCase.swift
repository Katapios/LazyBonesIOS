import Foundation

public protocol SaveAutoSendSettingsUseCase {
    func execute(_ settings: AutoSendSettings)
}
