import Foundation
import BackgroundTasks

/// Сервис для автоматической отправки отчетов в Telegram
protocol PostTelegramServiceProtocol {
    /// Отправить отчет в Telegram
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void)
    
    /// Выполнить автоматическую отправку отчетов
    func performAutoSendReport()
    
    /// Отправить все неотправленные отчеты за сегодня
    func autoSendAllReportsForToday()
    
    /// Отправить неотправленные отчеты за предыдущие дни
    func sendUnsentReportsFromPreviousDays()
}

class PostTelegramService: PostTelegramServiceProtocol {
    private let telegramService: TelegramServiceProtocol
    private let userDefaultsManager: UserDefaultsManagerProtocol
    
    init(telegramService: TelegramServiceProtocol, userDefaultsManager: UserDefaultsManagerProtocol) {
        self.telegramService = telegramService
        self.userDefaultsManager = userDefaultsManager
    }
    
    // MARK: - Public Methods
    
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) {
        Logger.info("Sending to Telegram: \(text.prefix(100))...", log: Logger.telegram)
        
        // Получаем chatId из userDefaultsManager
        guard let chatId = userDefaultsManager.string(forKey: "telegramChatId"), !chatId.isEmpty else {
            Logger.error("Telegram chatId is missing", log: Logger.telegram)
            completion(false)
            return
        }
        
        Task {
            do {
                try await telegramService.sendMessage(text, to: chatId)
                await MainActor.run {
                    completion(true)
                }
                Logger.info("Message sent successfully", log: Logger.telegram)
            } catch {
                await MainActor.run {
                    completion(false)
                }
                Logger.error("Failed to send message: \(error)", log: Logger.telegram)
            }
        }
    }
    
    func performAutoSendReport() {
        Logger.info("Performing auto send report", log: Logger.telegram)
        
        let posts = loadPosts()
        let today = Date()
        let calendar = Calendar.current
        
        // Получаем отчеты за сегодня
        let regular = posts.first(where: { $0.type == .regular && calendar.isDate($0.date, inSameDayAs: today) })
        let customReport = posts.first(where: { $0.type == .custom && calendar.isDate($0.date, inSameDayAs: today) })
        
        // Проверяем, отправлял ли пользователь отчеты вручную
        let regularManuallySent = regular?.published ?? false
        let customManuallySent = customReport?.published ?? false
        
        // Если пользователь отправил оба отчета вручную, автоотправка не нужна
        if regularManuallySent && customManuallySent {
            Logger.info("Both reports already sent manually, skipping auto-send", log: Logger.telegram)
            return
        }
        
        var toSend = 0
        let totalReports = 2
        
        // --- Обычный отчет ---
        if let regular = regular, !regular.goodItems.isEmpty {
            if !regularManuallySent {
                toSend += 1
                sendToTelegram(text: formatRegularReport(regular)) { _ in
                    toSend -= 1
                    if toSend == 0 {
                        Logger.info("Auto-send completed", log: Logger.telegram)
                    }
                }
            }
        }
        
        // --- Кастомный отчет ---
        if let custom = customReport, !custom.goodItems.isEmpty {
            if !customManuallySent {
                toSend += 1
                sendToTelegram(text: formatCustomReport(custom)) { _ in
                    toSend -= 1
                    if toSend == 0 {
                        Logger.info("Auto-send completed", log: Logger.telegram)
                    }
                }
            }
        }
        
        // --- Если нет ни одного отчета ---
        if customReport == nil && regular == nil {
            toSend += 1
            sendToTelegram(text: "За сегодня не найдено ни одного отчета.") { _ in
                toSend -= 1
                if toSend == 0 {
                    Logger.info("Auto-send completed", log: Logger.telegram)
                }
            }
        }
        
        Logger.info("Auto-send initiated for \(toSend) reports", log: Logger.telegram)
    }
    
    func autoSendAllReportsForToday() {
        Logger.info("Auto-sending all reports for today", log: Logger.telegram)
        performAutoSendReport()
    }
    
    func sendUnsentReportsFromPreviousDays() {
        Logger.info("Sending unsent reports from previous days", log: Logger.telegram)
        
        let posts = loadPosts()
        let today = Date()
        let calendar = Calendar.current
        
        // Группируем по дням
        let groupedPosts = Dictionary(grouping: posts) { post in
            calendar.startOfDay(for: post.date)
        }
        
        // Сортируем дни (от старых к новым)
        let sortedDays = groupedPosts.keys.sorted()
        
        for day in sortedDays {
            // Пропускаем сегодняшний день
            if calendar.isDate(day, inSameDayAs: today) {
                continue
            }
            
            let dayPosts = groupedPosts[day] ?? []
            let regular = dayPosts.first(where: { $0.type == .regular })
            let custom = dayPosts.first(where: { $0.type == .custom })
            
            // Если есть отчеты, но они не отправлены
            if (regular != nil || custom != nil) && !hasReportsBeenSent(for: day) {
                sendDayReport(regular: regular, custom: custom, day: day)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPosts() -> [Post] {
        return userDefaultsManager.loadPosts()
    }
    
    private func hasReportsBeenSent(for day: Date) -> Bool {
        let key = "reports_sent_\(DateUtils.formatDate(day))"
        return userDefaultsManager.bool(forKey: key)
    }
    
    private func markReportsAsSent(for day: Date) {
        let key = "reports_sent_\(DateUtils.formatDate(day))"
        userDefaultsManager.set(true, forKey: key)
    }
    
    private func formatRegularReport(_ post: Post) -> String {
        let deviceName = userDefaultsManager.string(forKey: "deviceName") ?? "Unknown Device"
        if let telegramService = telegramService as? TelegramService {
            return telegramService.formatRegularReportForTelegram(post, deviceName: deviceName)
        } else {
            Logger.error("telegramService is not TelegramService", log: Logger.telegram)
            return "[Ошибка форматирования отчёта]"
        }
    }
    
    private func formatCustomReport(_ post: Post) -> String {
        let deviceName = userDefaultsManager.string(forKey: "deviceName") ?? "Unknown Device"
        if let telegramService = telegramService as? TelegramService {
            return telegramService.formatCustomReportForTelegram(post, deviceName: deviceName)
        } else {
            Logger.error("telegramService is not TelegramService", log: Logger.telegram)
            return "[Ошибка форматирования отчёта]"
        }
    }
    
    private func sendDayReport(regular: Post?, custom: Post?, day: Date) {
        var reportText = "📅 Отчет за \(DateUtils.formatDate(day)):\n\n"
        
        if let regular = regular {
            reportText += "✅ Обычный отчет:\n"
            reportText += formatRegularReport(regular)
            reportText += "\n\n"
        }
        
        if let custom = custom {
            reportText += "📝 Кастомный отчет:\n"
            reportText += formatCustomReport(custom)
        }
        
        if regular == nil && custom == nil {
            reportText += "❌ Отчеты не найдены"
        }
        
        sendToTelegram(text: reportText) { success in
            if success {
                self.markReportsAsSent(for: day)
                Logger.info("Day report sent successfully for \(DateUtils.formatDate(day))", log: Logger.telegram)
            }
        }
    }
} 