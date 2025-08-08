import Foundation

/// Настройки уведомлений
public struct NotificationSettings: Equatable, Codable {
    /// Включены ли уведомления
    public let isEnabled: Bool
    /// Режим уведомлений
    public let mode: NotificationMode
    /// Интервал в часах между уведомлениями
    public let intervalHours: Int
    /// Час начала уведомлений
    public let startHour: Int
    /// Час окончания уведомлений
    public let endHour: Int
    
    public init(
        isEnabled: Bool = false,
        mode: NotificationMode = .hourly,
        intervalHours: Int = 1,
        startHour: Int = 9,
        endHour: Int = 22
    ) {
        self.isEnabled = isEnabled
        self.mode = mode
        self.intervalHours = intervalHours
        self.startHour = startHour
        self.endHour = endHour
    }
}

/// Режим уведомлений
public enum NotificationMode: String, Codable, CaseIterable, Identifiable {
    case hourly = "hourly"
    case daily = "daily"
    case custom = "custom"
    case twice = "twice"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .hourly: return "Каждый час"
        case .daily: return "Раз в день"
        case .custom: return "Кастомный"
        case .twice: return "Дважды в день"
        }
    }
}
