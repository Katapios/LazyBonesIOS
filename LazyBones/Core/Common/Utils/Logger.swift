import Foundation
import os.log

/// Утилита для логирования
struct Logger {
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lazybones"
    
    /// Логгер для общих сообщений
    static let general = OSLog(subsystem: subsystem, category: "general")
    
    /// Логгер для сетевых запросов
    static let networking = OSLog(subsystem: subsystem, category: "networking")
    
    /// Логгер для работы с данными
    static let data = OSLog(subsystem: subsystem, category: "data")
    
    /// Логгер для UI событий
    static let ui = OSLog(subsystem: subsystem, category: "ui")
    
    /// Логгер для фоновых задач
    static let background = OSLog(subsystem: subsystem, category: "background")
    
    /// Логгер для уведомлений
    static let notifications = OSLog(subsystem: subsystem, category: "notifications")
    
    /// Логгер для Telegram
    static let telegram = OSLog(subsystem: subsystem, category: "telegram")
    
    /// Логгер для таймеров
    static let timer = OSLog(subsystem: subsystem, category: "timer")
    
    /// Логгер для ошибок
    static let error = OSLog(subsystem: subsystem, category: "error")
    
    /// Логировать информационное сообщение
    static func info(_ message: String, log: OSLog = general) {
        os_log(.info, log: log, "%{public}@", message)
        #if DEBUG
        print("[INFO] \(message)")
        #endif
    }
    
    /// Логировать отладочное сообщение
    static func debug(_ message: String, log: OSLog = general) {
        #if DEBUG
        os_log(.debug, log: log, "%{public}@", message)
        print("[DEBUG] \(message)")
        #endif
    }
    
    /// Логировать предупреждение
    static func warning(_ message: String, log: OSLog = general) {
        os_log(.default, log: log, "%{public}@", message)
        #if DEBUG
        print("[WARNING] \(message)")
        #endif
    }
    
    /// Логировать ошибку
    static func error(_ message: String, log: OSLog = error) {
        os_log(.error, log: log, "%{public}@", message)
        #if DEBUG
        print("[ERROR] \(message)")
        #endif
    }
    
    /// Логировать критическую ошибку
    static func critical(_ message: String, log: OSLog = error) {
        os_log(.fault, log: log, "%{public}@", message)
        #if DEBUG
        print("[CRITICAL] \(message)")
        #endif
    }
} 