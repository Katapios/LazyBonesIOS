import Foundation
import SwiftUI
import Combine
import WatchConnectivity

final class WatchMainViewModel: ObservableObject {
    @Published var status: String = "notStarted"
    @Published var timeLeft: String = "До старта: 00:00:00"
    @Published var progress: Double = 0.0
    @Published var goodItemsCount: Int = 0
    @Published var badItemsCount: Int = 0
    @Published var planItems: [String] = []
    @Published var motivationalSlogan: String = ""
    
    private let userDefaults = WatchConfig.sharedUserDefaults
    private var updateTimer: Timer?
    private let connectivityService = WatchConnectivityService.shared
    private var userDefaultsObserver: NSObjectProtocol?
    
    init() {
        setupWatchConnectivity()
        startUpdateTimer()
        setupUserDefaultsObserver()
        loadData()
    }
    
    deinit {
        updateTimer?.invalidate()
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupWatchConnectivity() {
        // Подписываемся на получение данных через WatchConnectivity
        connectivityService.onDataReceived = { [weak self] reportData in
            Task { @MainActor [weak self] in
                self?.updateFromReportData(reportData)
            }
        }
    }
    
    private func setupUserDefaultsObserver() {
        // Подписываемся на изменения UserDefaults
        // Для App Groups это может не работать напрямую, но попробуем
        // Основная синхронизация будет через WatchConnectivity
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            #if DEBUG
            print("[WatchApp] UserDefaults changed, reloading data")
            #endif
            self?.loadFromUserDefaults()
        }
    }
    
    private func updateFromReportData(_ reportData: WatchReportData) {
        #if DEBUG
        print("[WatchApp] Updating from WatchConnectivity data")
        #endif
        status = reportData.status
        timeLeft = reportData.timeLeft
        progress = reportData.progress
        goodItemsCount = reportData.goodItemsCount
        badItemsCount = reportData.badItemsCount
        planItems = reportData.planItems
        motivationalSlogan = reportData.motivationalSlogan
        
        // Также сохраняем в UserDefaults для компликаций
        saveToUserDefaults(reportData)
    }
    
    private func saveToUserDefaults(_ reportData: WatchReportData) {
        userDefaults.set(reportData.status, forKey: "watchStatus")
        userDefaults.set(reportData.timeLeft, forKey: "watchTimeLeft")
        userDefaults.set(reportData.progress, forKey: "watchProgress")
        userDefaults.set(reportData.goodItemsCount, forKey: "watchGoodItemsCount")
        userDefaults.set(reportData.badItemsCount, forKey: "watchBadItemsCount")
        userDefaults.set(reportData.planItems, forKey: "watchPlanItems")
        userDefaults.set(reportData.motivationalSlogan, forKey: "watchMotivationalSlogan")
        userDefaults.synchronize()
    }
    
    func loadData() {
        loadFromUserDefaults()
    }
    
    func refreshData() async {
        // Запрашиваем обновление через WatchConnectivity
        connectivityService.requestUpdate()
        // Также загружаем из UserDefaults на случай, если WatchConnectivity недоступен
        loadFromUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        // Загружаем данные из UserDefaults
        status = userDefaults.string(forKey: "watchStatus") ?? "notStarted"
        timeLeft = userDefaults.string(forKey: "watchTimeLeft") ?? "До старта: 00:00:00"
        progress = userDefaults.double(forKey: "watchProgress")
        goodItemsCount = userDefaults.integer(forKey: "watchGoodItemsCount")
        badItemsCount = userDefaults.integer(forKey: "watchBadItemsCount")
        planItems = userDefaults.stringArray(forKey: "watchPlanItems") ?? []
        motivationalSlogan = userDefaults.string(forKey: "watchMotivationalSlogan") ?? ""
        
        // Также проверяем исходные ключи на случай, если данные еще не были обработаны WatchSyncService
        if status == "notStarted", let rawStatus = userDefaults.string(forKey: "reportStatus") {
            status = rawStatus
        }
        if timeLeft == "До старта: 00:00:00", let rawTimeLeft = userDefaults.string(forKey: "timerTimeLeft") {
            timeLeft = rawTimeLeft
        }
        if progress == 0.0 {
            let rawProgress = userDefaults.double(forKey: "timerProgress")
            if rawProgress > 0 {
                progress = rawProgress
            }
        }
        
        #if DEBUG
        print("[WatchApp] Loaded: status=\(status), timeLeft=\(timeLeft), progress=\(progress), good=\(goodItemsCount), bad=\(badItemsCount)")
        #endif
    }
    
    
    func sendReportItem(_ item: String, isGood: Bool) {
        // Отправляем элемент на iPhone через WatchConnectivity
        guard let session = connectivityService.session, session.isReachable else {
            // Если iPhone недоступен, сохраняем локально для последующей отправки
            let key = isGood ? "watchLocalGoodItems" : "watchLocalBadItems"
            var items = userDefaults.stringArray(forKey: key) ?? []
            items.append(item)
            userDefaults.set(items, forKey: key)
            userDefaults.synchronize()
            
            // Обновляем счетчики локально
            if isGood {
                goodItemsCount += 1
            } else {
                badItemsCount += 1
            }
            return
        }
        
        // Отправляем через WatchConnectivity
        let message: [String: Any] = [
            "type": "addReportItem",
            "item": item,
            "isGood": isGood
        ]
        
        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor [weak self] in
                if let status = response["status"] as? String, status == "received" {
                    #if DEBUG
                    print("[WatchApp] Item sent successfully: \(item), isGood: \(isGood)")
                    #endif
                    // Обновляем счетчики после успешной отправки
                    if isGood {
                        self?.goodItemsCount += 1
                    } else {
                        self?.badItemsCount += 1
                    }
                }
            }
        }) { error in
            #if DEBUG
            print("[WatchApp] Error sending item: \(error.localizedDescription)")
            #endif
            // При ошибке сохраняем локально
            Task { @MainActor [weak self] in
                let key = isGood ? "watchLocalGoodItems" : "watchLocalBadItems"
                var items = self?.userDefaults.stringArray(forKey: key) ?? []
                items.append(item)
                self?.userDefaults.set(items, forKey: key)
                self?.userDefaults.synchronize()
            }
        }
    }
    
    private func startUpdateTimer() {
        // Уменьшаем интервал до 10 секунд для более быстрого обновления
        // Основные обновления будут приходить через WatchConnectivity
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                // Запрашиваем обновление через WatchConnectivity
                self.connectivityService.requestUpdate()
                // Также загружаем из UserDefaults
                self.loadFromUserDefaults()
            }
        }
        // Добавляем таймер в RunLoop для правильной работы
        if let timer = updateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

