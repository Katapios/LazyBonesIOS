import Foundation
import SwiftUI

/// ViewModel-адаптер для MainView, который оборачивает PostStore
/// Учитывает разные типы отчетов и их связи со статусной моделью, тегами и бэкграунд тасками
@MainActor
class MainViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var store: PostStore
    @Published var currentTime = Date()
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var statusChangeObserver: NSObjectProtocol?
    private let tagProvider: TagProviderProtocol? = DependencyContainer.shared.resolve(TagProviderProtocol.self)
    
    // MARK: - Initialization
    init(store: PostStore) {
        self.store = store
        setupTimer()

        // Подписываемся на изменения статуса (разблокировка из настроек и др.)
        statusChangeObserver = NotificationCenter.default.addObserver(
            forName: .reportStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Статус уже пересчитан менеджером и проброшен в PostStore через нотификацию
                // Обновим только время, чтобы перерисовать UI без повторного пересчета
                self.currentTime = Date()
            }
        }
    }
    
    deinit {
        // Timer invalidation in deinit is safe without MainActor
        // since we're just calling invalidate() which is thread-safe
        timer?.invalidate()
        if let token = statusChangeObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    // MARK: - Timer Management
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }
    
    // MARK: - Report Status Management
    var reportStatus: ReportStatus {
        store.reportStatus
    }
    
    var isReportPeriodActive: Bool {
        store.isReportPeriodActive()
    }
    
    var reportStatusText: String {
        switch store.reportStatus {
        case .inProgress: return "Отчет заполняется..."
        case .notStarted: return "Заполни отчет!"
        case .notCreated: return "Отчёт не создан"
        case .notSent: return "Отчёт не отправлен"
        case .sent: return "Отчет отправлен"
        }
    }
    
    var reportStatusColor: Color {
        switch store.reportStatus {
        case .inProgress: return .black
        case .notStarted: return .gray
        case .notCreated: return .gray
        case .notSent: return .gray
        case .sent: return .black
        }
    }
    
    // MARK: - Today's Report Management
    var postForToday: Post? {
        store.posts.first(where: {
            Calendar.current.isDateInToday($0.date)
        })
    }
    
    var hasReportForToday: Bool {
        postForToday != nil
    }
    
    var canEditReport: Bool {
        // Базовое правило: активный период и редактируемые статусы
        if isReportPeriodActive && (store.reportStatus == .notStarted || store.reportStatus == .inProgress) {
            return true
        }
        // Исключение: при форс‑разблокировке разрешаем редактирование даже если статус .sent
        if store.forceUnlock && store.reportStatus == .sent {
            return true
        }
        // Остальные случаи — как раньше
        return false
    }
    
    var buttonTitle: String {
        // При форс‑разблокировке и статусе .sent — предлагаем создать новый отчёт
        if store.forceUnlock && store.reportStatus == .sent {
            return "Создать отчёт"
        }
        return hasReportForToday ? "Редактировать отчёт" : "Создать отчёт"
    }
    
    var buttonIcon: String {
        hasReportForToday ? "pencil.circle.fill" : "plus.circle.fill"
    }
    
    var buttonColor: Color {
        if store.forceUnlock { return .black }
        return (store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent) ? .gray : .black
    }
    
    // MARK: - Progress Counters (учитывает разные типы отчетов)
    var goodCountToday: Int {
        var total = 0
        
        // Обычный отчет за сегодня
        if let regular = store.posts.first(where: { 
            $0.type == .regular && Calendar.current.isDateInToday($0.date) 
        }) {
            total += regular.goodItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
        
        // Кастомный оцененный отчет за сегодня
        if let custom = store.posts.first(where: { 
            $0.type == .custom && 
            Calendar.current.isDateInToday($0.date) && 
            $0.isEvaluated == true 
        }), let results = custom.evaluationResults {
            total += results.filter { $0 }.count
        }
        
        return total
    }
    
    var badCountToday: Int {
        var total = 0
        
        // Обычный отчет за сегодня
        if let regular = store.posts.first(where: { 
            $0.type == .regular && Calendar.current.isDateInToday($0.date) 
        }) {
            total += regular.badItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
        
        // Кастомный оцененный отчет за сегодня
        if let custom = store.posts.first(where: { 
            $0.type == .custom && 
            Calendar.current.isDateInToday($0.date) && 
            $0.isEvaluated == true 
        }), let results = custom.evaluationResults {
            total += results.filter { !$0 }.count
        }
        
        return total
    }
    
    // MARK: - Timer Management (связь с бэкграунд тасками)
    var timeLeft: String {
        store.timeLeft
    }
    
    var timerTimeTextOnly: String {
        let value = store.timeLeft
        if let range = value.range(of: ": ") {
            return String(value[range.upperBound...])
        }
        return value
    }
    
    var timerLabel: String {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return "Новый день"
        }

        // Исключение: если статус отправлен, всегда показываем обратный отсчет до СТАРТА
        if store.reportStatus == .sent {
            return "До старта"
        }
        
        if now < start {
            return "До старта"
        } else if now >= start && now < end {
            return "До конца"
        } else {
            // После конца — всегда показываем «До старта» следующего дня
            return "До старта"
        }
    }
    
    var timerTimeTextOnlyForStatus: String {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return "00:00:00"
        }

        // Исключение: если отправлено — считаем до СЛЕДУЮЩЕГО старта
        if store.reportStatus == .sent {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: store.notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        }
        
        if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: store.notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        }
    }
    
    var timerProgress: Double {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return 0.0
        }

        // Исключение: если отправлено — прогресс 0.0
        if store.reportStatus == .sent {
            return 0.0
        }
        
        if now < start {
            return 0.0
        } else if now >= start && now < end {
            let totalDuration = end.timeIntervalSince(start)
            let elapsed = now.timeIntervalSince(start)
            return min(max(elapsed / totalDuration, 0.0), 1.0)
        } else {
            // После конца — прогресс сбрасываем (таймер считает до старта)
            return 0.0
        }
    }
    
    // MARK: - Actions
    func checkForNewDay() {
        store.checkForNewDay()
    }
    
    func switchToPlanningTab() {
        // Этот метод будет вызываться из MainView для переключения на вкладку планирования
        // AppCoordinator будет обрабатывать это через callback
    }
    
    // MARK: - Tag Management (связь с тегами)
    var goodTags: [String] {
        !store.goodTags.isEmpty ? store.goodTags : (tagProvider?.goodTags ?? [])
    }
    
    var badTags: [String] {
        !store.badTags.isEmpty ? store.badTags : (tagProvider?.badTags ?? [])
    }
    
    // MARK: - Background Task Management
    var notificationStartHour: Int {
        store.notificationStartHour
    }
    
    var notificationEndHour: Int {
        store.notificationEndHour
    }
    
    var currentDay: Date {
        store.currentDay
    }
} 