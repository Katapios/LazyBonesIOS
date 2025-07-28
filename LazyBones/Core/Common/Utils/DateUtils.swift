import Foundation

/// Утилиты для работы с датами
struct DateUtils {
    
    /// Получить начало дня для указанной даты
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// Получить конец дня для указанной даты
    static func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
    
    /// Проверить, является ли дата сегодняшней
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /// Проверить, находятся ли две даты в одном дне
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    /// Получить дату с установленным временем
    static func dateWithTime(hour: Int, minute: Int, second: Int, of date: Date) -> Date {
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: date) ?? date
    }
    
    /// Получить дату завтра
    static func tomorrow(from date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }
    
    /// Получить дату вчера
    static func yesterday(from date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
    }
    
    /// Форматировать дату в строку
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    /// Форматировать время в строку
    static func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = style
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    /// Форматировать дату и время в строку
    static func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
} 