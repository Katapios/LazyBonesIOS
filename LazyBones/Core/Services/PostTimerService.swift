import Foundation
import Combine

/// Сервис для управления таймерами отчетов
protocol PostTimerServiceProtocol {
    /// Запустить таймер
    func startTimer()
    
    /// Остановить таймер
    func stopTimer()
    
    /// Обновить время до следующего события
    func updateTimeLeft()
    
    /// Обновить статус отчета
    func updateReportStatus(_ status: ReportStatus)
    
    /// Получить текущее время до события
    var timeLeft: String { get }
    
    /// Получить прогресс времени
    var timeProgress: Double { get }
}

class PostTimerService: PostTimerServiceProtocol, ObservableObject {
    @Published var timeLeft: String = ""
    @Published var timeProgress: Double = 0.0
    
    private var timer: Timer?
    private let userDefaultsManager: UserDefaultsManagerProtocol
    private let onTimeUpdate: (String, Double) -> Void
    private var currentReportStatus: ReportStatus = .notStarted
    
    init(userDefaultsManager: UserDefaultsManagerProtocol, onTimeUpdate: @escaping (String, Double) -> Void) {
        self.userDefaultsManager = userDefaultsManager
        self.onTimeUpdate = onTimeUpdate
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Public Methods
    
    func startTimer() {
        stopTimer()
        updateTimeLeft()
        
        // Умная логика обновления: чаще в критических моментах
        let now = Date()
        let calendar = Calendar.current
        let startHour = getNotificationStartHour()
        let endHour = getNotificationEndHour()
        
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now)!
        
        // Если до начала или конца периода меньше часа - обновляем каждые 10 секунд
        let timeToStart = start.timeIntervalSince(now)
        let timeToEnd = end.timeIntervalSince(now)
        let isCriticalTime = (timeToStart > 0 && timeToStart < 3600) || (timeToEnd > 0 && timeToEnd < 3600)
        
        let interval: TimeInterval = isCriticalTime ? 10 : 30
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateTimeLeft()
        }
        
        Logger.info("Timer started with interval: \(interval)s", log: Logger.timer)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        Logger.info("Timer stopped", log: Logger.timer)
    }
    
    func updateTimeLeft() {
        let calendar = Calendar.current
        let now = Date()
        let startHour = getNotificationStartHour()
        let endHour = getNotificationEndHour()
        
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now)!
        
        // Вычисляем новое значение timeLeft
        let newTimeLeft: String
        let newProgress: Double
        
        if currentReportStatus == .sent || currentReportStatus == .notSent {
            // Для отправленного отчёта и статуса не отправлен (после окончания периода)
            // показываем обратный отсчёт до следующего старта (завтра)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            newTimeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
            newProgress = 0.0
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            newTimeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
            newProgress = 0.0
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            newTimeLeft = "До конца: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
            let totalDuration = end.timeIntervalSince(start)
            let elapsed = now.timeIntervalSince(start)
            newProgress = min(elapsed / totalDuration, 1.0)
        } else {
            newTimeLeft = "Время отчёта истекло"
            newProgress = 1.0
        }
        
        // Обновляем только если значение изменилось
        if timeLeft != newTimeLeft || abs(timeProgress - newProgress) > 0.01 {
            timeLeft = newTimeLeft
            timeProgress = newProgress
            onTimeUpdate(newTimeLeft, newProgress)
        }
    }
    
    func updateReportStatus(_ status: ReportStatus) {
        currentReportStatus = status
        // Обновляем время сразу после изменения статуса
        updateTimeLeft()
    }
    
    // MARK: - Private Methods
    
    private func getNotificationStartHour() -> Int {
        return userDefaultsManager.get(Int.self, forKey: "notificationStartHour", defaultValue: 8)
    }
    
    private func getNotificationEndHour() -> Int {
        return userDefaultsManager.get(Int.self, forKey: "notificationEndHour", defaultValue: 22)
    }
} 