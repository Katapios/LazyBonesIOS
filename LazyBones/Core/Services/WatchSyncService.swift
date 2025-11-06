import Foundation
import WatchConnectivity
import WidgetKit

// Импортируем модель данных из Watch App (нужно будет сделать общий модуль или скопировать)
// Временно определяем здесь для использования в основном приложении
struct WatchReportData: Codable {
    let status: String
    let timeLeft: String
    let progress: Double
    let goodItemsCount: Int
    let badItemsCount: Int
    let planItems: [String]
    let motivationalSlogan: String
}

/// Сервис для синхронизации данных с Apple Watch
@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()
    
    private var session: WCSession?
    private var statusObserver: NSObjectProtocol?
    private var timerObserver: NSObjectProtocol?
    
    private override init() {
        super.init()
        print("[WatchSync] WatchSyncService initialized")
        
        // Проверяем App Group сразу при инициализации
        let defaults = AppConfig.sharedUserDefaults
        if defaults == UserDefaults.standard {
            print("[WatchSync] ERROR: AppConfig.sharedUserDefaults returned UserDefaults.standard!")
        } else {
            print("[WatchSync] App Group UserDefaults available: \(AppConfig.appGroup)")
            // Проверяем тестовый ключ от приложения
            if let testValue = defaults.string(forKey: "watchTestFromAppInit") {
                print("[WatchSync] Test key from app init found: \(testValue)")
            }
        }
        
        setupWatchConnectivity()
        setupObservers()
        // Принудительно обновляем данные при инициализации
        Task { @MainActor in
            // Небольшая задержка, чтобы убедиться, что все сервисы инициализированы
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            print("[WatchSync] Calling updateWatchData() after initialization delay")
            updateWatchData()
        }
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("[WatchSync] WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    private func setupObservers() {
        // Подписка на изменения статуса
        statusObserver = NotificationCenter.default.addObserver(
            forName: .reportStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleStatusChange(notification)
            }
        }
        
        // Подписка на изменения таймера (через PostTimerService)
        timerObserver = NotificationCenter.default.addObserver(
            forName: .reportPeriodActivityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateWatchData()
            }
        }
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = timerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func updateWatchData() {
        print("[WatchSync] updateWatchData() called")
        // Всегда сохраняем данные в UserDefaults для Watch App и компликаций
        let defaults = AppConfig.sharedUserDefaults
        let status = defaults.string(forKey: "reportStatus") ?? "notStarted"
        print("[WatchSync] Current reportStatus from UserDefaults: \(status)")
        
        // Получаем данные таймера
        let timeLeft = getTimeLeft()
        let progress = getProgress()
        
        // Получаем данные отчета
        let reportData = buildReportData(status: status, timeLeft: timeLeft, progress: progress)
        
        // Сохраняем в UserDefaults (это основной способ синхронизации с Watch)
        saveToUserDefaults(reportData)
        
        // Также отправляем через WatchConnectivity если доступен (опционально)
        guard let session = session else {
            print("[WatchSync] WCSession not available, data saved to UserDefaults only")
            return
        }
        
        // Отправляем данные через WatchConnectivity
        sendDataToWatch(reportData, session: session)
    }
    
    private func sendDataToWatch(_ reportData: WatchReportData, session: WCSession) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(reportData)
            let message: [String: Any] = [
                "type": "reportData",
                "data": data
            ]
            
            // Если Watch доступен, отправляем через sendMessage
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("[WatchSync] Error sending report data via sendMessage: \(error.localizedDescription)")
                }
                print("[WatchSync] Sent report data via sendMessage (Watch is reachable)")
            } else {
                // Если Watch недоступен, используем transferUserInfo для фоновой отправки
                session.transferUserInfo(message)
                print("[WatchSync] Queued report data via transferUserInfo (Watch not reachable, will be delivered when available)")
            }
        } catch {
            print("[WatchSync] Error encoding report data: \(error)")
        }
    }
    
    private func saveToUserDefaults(_ report: WatchReportData) {
        let defaults = AppConfig.sharedUserDefaults
        
        // Проверяем, что UserDefaults действительно использует App Group
        if defaults == UserDefaults.standard {
            print("[WatchSync] ERROR: AppConfig.sharedUserDefaults returned UserDefaults.standard instead of App Group!")
            return // Не сохраняем, если не используем App Group
        } else {
            print("[WatchSync] Using App Group UserDefaults: \(AppConfig.appGroup)")
        }
        
        // Тестовая запись для проверки App Group
        defaults.set("test_from_iphone_\(Date().timeIntervalSince1970)", forKey: "watchTestFromiPhone")
        print("[WatchSync] Test write to App Group: watchTestFromiPhone")
        
        // Записываем данные
        defaults.set(report.status, forKey: "watchStatus")
        defaults.set(report.timeLeft, forKey: "watchTimeLeft")
        defaults.set(report.progress, forKey: "watchProgress")
        defaults.set(report.goodItemsCount, forKey: "watchGoodItemsCount")
        defaults.set(report.badItemsCount, forKey: "watchBadItemsCount")
        defaults.set(report.planItems, forKey: "watchPlanItems")
        defaults.set(report.motivationalSlogan, forKey: "watchMotivationalSlogan")
        
        // Принудительная синхронизация
        // Примечание: synchronize() устарел и может возвращать false, но это не критично для App Groups
        // App Groups синхронизируются автоматически
        let syncResult = defaults.synchronize()
        print("[WatchSync] synchronize() result: \(syncResult) (false is OK for App Groups)")
        
        // Альтернативный способ записи через persistentDomain для надежности
        // Это может помочь, если есть проблемы с синхронизацией между приложениями
        let suiteName = AppConfig.appGroup
        var domain = defaults.persistentDomain(forName: suiteName) ?? [:]
        print("[WatchSync] Current domain has \(domain.keys.count) keys before update")
        
        domain["watchStatus"] = report.status
        domain["watchTimeLeft"] = report.timeLeft
        domain["watchProgress"] = report.progress
        domain["watchGoodItemsCount"] = report.goodItemsCount
        domain["watchBadItemsCount"] = report.badItemsCount
        domain["watchPlanItems"] = report.planItems
        domain["watchMotivationalSlogan"] = report.motivationalSlogan
        domain["watchTestFromiPhone"] = "test_from_iphone_\(Date().timeIntervalSince1970)"
        
        defaults.setPersistentDomain(domain, forName: suiteName)
        print("[WatchSync] Used setPersistentDomain for forced write to suite: \(suiteName), domain now has \(domain.keys.count) keys")
        
        // Проверяем, что domain действительно обновился
        if let updatedDomain = defaults.persistentDomain(forName: suiteName) {
            print("[WatchSync] Verification - domain after write has \(updatedDomain.keys.count) keys")
            let watchKeys = updatedDomain.keys.filter { $0.hasPrefix("watch") }
            print("[WatchSync] Watch keys in domain: \(watchKeys.count)")
        }
        
        // Проверяем, что данные действительно сохранились
        let savedStatus = defaults.string(forKey: "watchStatus")
        let savedTimeLeft = defaults.string(forKey: "watchTimeLeft")
        let savedProgress = defaults.double(forKey: "watchProgress")
        print("[WatchSync] Verification - saved status: \(savedStatus ?? "nil"), saved timeLeft: \(savedTimeLeft ?? "nil"), saved progress: \(savedProgress)")
        
        // Проверяем тестовый ключ от Watch App
        if let testValue = defaults.string(forKey: "watchTestKey") {
            print("[WatchSync] Test key from Watch App found: watchTestKey = \(testValue)")
        }
        
        // Выводим все ключи с префиксом "watch"
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("watch") }
        print("[WatchSync] All keys with 'watch' prefix after save: \(Array(allKeys).sorted())")
        
        print("[WatchSync] Saved to UserDefaults: status=\(report.status), timeLeft=\(report.timeLeft), progress=\(report.progress), good=\(report.goodItemsCount), bad=\(report.badItemsCount), planItems=\(report.planItems.count), slogan=\(report.motivationalSlogan.prefix(30))")
    }
    
    private func handleStatusChange(_ notification: Notification) {
        updateWatchData()
    }
    
    private func getTimeLeft() -> String {
        // Получаем из PostTimerService через UserDefaults или напрямую
        // PostTimerService обновляет значения через onTimeUpdate callback
        let defaults = AppConfig.sharedUserDefaults
        if let timeLeft = defaults.string(forKey: "timerTimeLeft"), !timeLeft.isEmpty {
            return timeLeft
        }
        return "До старта: 00:00:00"
    }
    
    private func getProgress() -> Double {
        let defaults = AppConfig.sharedUserDefaults
        let progress = defaults.double(forKey: "timerProgress")
        return progress >= 0 && progress <= 1 ? progress : 0.0
    }
    
    /// Обновить данные таймера (вызывается из PostTimerService)
    func updateTimerData(timeLeft: String, progress: Double) {
        let defaults = AppConfig.sharedUserDefaults
        defaults.set(timeLeft, forKey: "timerTimeLeft")
        defaults.set(progress, forKey: "timerProgress")
        defaults.synchronize()
        
        // Обновляем Watch
        updateWatchData()
    }
    
    private func buildReportData(status: String, timeLeft: String, progress: Double) -> WatchReportData {
        let defaults = AppConfig.sharedUserDefaults
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Загружаем отчеты
        var goodItemsCount = 0
        var badItemsCount = 0
        var planItems: [String] = []
        
        if let postsData = defaults.data(forKey: "posts"),
           let posts = try? JSONDecoder().decode([Post].self, from: postsData) {
            // Находим regular отчет за сегодня
            if let todayReport = posts.first(where: { post in
                post.type == .regular && calendar.isDate(post.date, inSameDayAs: today)
            }) {
                goodItemsCount = todayReport.goodItems.count
                badItemsCount = todayReport.badItems.count
            }
            
            // Находим custom отчет за сегодня для плана
            if let customReport = posts.first(where: { post in
                post.type == .custom && calendar.isDate(post.date, inSameDayAs: today)
            }) {
                planItems = customReport.goodItems
            }
        }
        
        // Если regular отчет еще не сохранен, загружаем из черновика
        if goodItemsCount == 0 && badItemsCount == 0 {
            let draftKey = RegularReportDraftStorageKey.forDay(today)
            if let draftData = defaults.data(forKey: draftKey),
               let draft = try? JSONDecoder().decode(RegularReportDraft.self, from: draftData) {
                goodItemsCount = draft.good.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                badItemsCount = draft.bad.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            }
        }
        
        // Загружаем план из черновиков
        if planItems.isEmpty {
            let dateKey = DateFormatter.localizedString(from: today, dateStyle: .short, timeStyle: .none)
            let planKey = "plan_" + dateKey
            if let planData = defaults.data(forKey: planKey),
               let items = try? JSONDecoder().decode([String].self, from: planData) {
                planItems = items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
        }
        
        // Генерируем мотивационный лозунг (используем логику из виджета)
        let motivationalSlogan = generateMotivationalSlogan(planItems: planItems)
        
        return WatchReportData(
            status: status,
            timeLeft: timeLeft,
            progress: progress,
            goodItemsCount: goodItemsCount,
            badItemsCount: badItemsCount,
            planItems: planItems,
            motivationalSlogan: motivationalSlogan
        )
    }
    
    private func generateMotivationalSlogan(planItems: [String]) -> String {
        guard !planItems.isEmpty else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: Date())
        }
        
        let phrases = [
            "А не пора ли сделать",
            "Пора бы уже",
            "Может, стоит",
            "Время для"
        ]
        
        // Используем текущее время как seed для псевдослучайного выбора
        let now = Date()
        let quarterHourInterval = Int(now.timeIntervalSince1970 / 900) // 15 минут
        let phraseIndex = quarterHourInterval % phrases.count
        let itemIndex = quarterHourInterval % max(planItems.count, 1)
        
        let phrase = phrases[phraseIndex]
        let item = planItems[itemIndex]
        
        return "\(phrase) \(item)?"
    }
}

// MARK: - WCSessionDelegate
extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[WatchSync] Activation failed: \(error.localizedDescription)")
            } else {
                print("[WatchSync] Session activated with state: \(activationState.rawValue)")
                updateWatchData()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSync] Session became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            guard let type = message["type"] as? String else {
                replyHandler([:])
                return
            }
            
            switch type {
            case "addReportItem":
                if let item = message["item"] as? String,
                   let isGood = message["isGood"] as? Bool {
                    handleReportItemFromWatch(item: item, isGood: isGood)
                }
                replyHandler(["status": "received"])
            case "requestUpdate":
                // Отправляем данные сразу в ответе
                let defaults = AppConfig.sharedUserDefaults
                let status = defaults.string(forKey: "reportStatus") ?? "notStarted"
                let timeLeft = getTimeLeft()
                let progress = getProgress()
                let reportData = buildReportData(status: status, timeLeft: timeLeft, progress: progress)
                
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(reportData)
                    replyHandler([
                        "type": "reportData",
                        "data": data
                    ])
                    print("[WatchSync] Sent report data in reply to requestUpdate")
                } catch {
                    print("[WatchSync] Error encoding report data for reply: \(error)")
                    replyHandler(["error": error.localizedDescription])
                }
                
                // Также обновляем данные в UserDefaults
                updateWatchData()
            default:
                replyHandler([:])
            }
        }
    }
    
    // Оставляем старый метод для обратной совместимости
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let type = message["type"] as? String else { return }
            
            switch type {
            case "addReportItem":
                if let item = message["item"] as? String,
                   let isGood = message["isGood"] as? Bool {
                    handleReportItemFromWatch(item: item, isGood: isGood)
                }
            case "requestUpdate":
                updateWatchData()
            default:
                break
            }
        }
    }
    
    @MainActor
    private func handleReportItemFromWatch(item: String, isGood: Bool) {
        // Здесь можно добавить логику для обработки пунктов отчета с Watch
        // Например, добавить в текущий отчет через Use Case
        print("[WatchSync] Received report item from Watch: \(item), isGood: \(isGood)")
        // TODO: Интегрировать с CreateReportUseCase или PostRepository
    }
}


