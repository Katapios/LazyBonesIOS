import Foundation

public struct AutoSendSettings: Equatable {
    public var enabled: Bool
    public var time: Date
    public var lastStatus: String?
    public var lastDate: Date?
    
    public init(enabled: Bool, time: Date, lastStatus: String?, lastDate: Date?) {
        self.enabled = enabled
        self.time = time
        self.lastStatus = lastStatus
        self.lastDate = lastDate
    }
}
