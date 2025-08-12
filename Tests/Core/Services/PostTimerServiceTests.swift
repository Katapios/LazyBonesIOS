import XCTest
@testable import LazyBones

final class PostTimerServiceTests: XCTestCase {
    // Локальный мок UserDefaultsManager с настраиваемыми часами
    final class PTST_UserDefaultsMock: UserDefaultsManagerProtocol {
        var startHour: Int = 8
        var endHour: Int = 22
        
        func set<T>(_ value: T, forKey key: String) {}
        func get<T>(_ type: T.Type, forKey key: String) -> T? { return nil }
        func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T { return defaultValue }
        func remove(forKey key: String) {}
        func hasValue(forKey key: String) -> Bool { return false }
        func bool(forKey key: String) -> Bool { return false }
        func string(forKey key: String) -> String? { return nil }
        func integer(forKey key: String) -> Int { return 0 }
        func data(forKey key: String) -> Data? { return nil }
        func loadPosts() -> [Post] { return [] }
        func savePosts(_ posts: [Post]) {}
        func saveTelegramSettings(token: String?, chatId: String?, botId: String?) {}
        func loadTelegramSettings() -> (token: String?, chatId: String?, botId: String?) { return (nil, nil, nil) }
        func saveNotificationSettings(enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {}
        func loadNotificationSettings() -> (enabled: Bool, intervalHours: Int, startHour: Int, endHour: Int, mode: String) {
            return (true, 1, startHour, endHour, "hourly")
        }
    }
    
    func makeService(start: Int, end: Int) -> (PostTimerService, PTST_UserDefaultsMock, () -> (String, Double)) {
        let udm = PTST_UserDefaultsMock()
        udm.startHour = ((start % 24) + 24) % 24
        udm.endHour = ((end % 24) + 24) % 24
        var last: (String, Double) = ("", 0)
        let service = PostTimerService(userDefaultsManager: udm) { tl, pr in
            last = (tl, pr)
        }
        return (service, udm, { last })
    }
    
    func test_beforeStart_showsCountdownToStart_andZeroProgress() {
        let nowHour = Calendar.current.component(.hour, from: Date())
        // Выставим старт через 2 часа, конец еще через час => сейчас ДО старта
        let (service, _, last) = makeService(start: nowHour + 2, end: nowHour + 3)
        service.updateTimeLeft()
        let (label, progress) = last()
        XCTAssertTrue(label.hasPrefix("До старта:"))
        XCTAssertEqual(progress, 0.0, accuracy: 1e-6)
    }
    
    func test_duringPeriod_showsCountdownToEnd_andProgressIn01() {
        let nowHour = Calendar.current.component(.hour, from: Date())
        // Старт = текущий час, конец = следующий => сейчас В ПЕРИОДЕ
        let (service, _, last) = makeService(start: nowHour, end: nowHour + 1)
        service.updateTimeLeft()
        let (label, progress) = last()
        XCTAssertTrue(label.hasPrefix("До конца:"))
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }
    
    func test_afterEnd_showsCountdownToNextStart_andZeroProgress() {
        let nowHour = Calendar.current.component(.hour, from: Date())
        // Старт за 2 часа, конец за 1 час => сейчас ПОСЛЕ конца
        let (service, _, last) = makeService(start: nowHour - 2, end: nowHour - 1)
        service.updateTimeLeft()
        let (label, progress) = last()
        XCTAssertTrue(label.hasPrefix("До старта:"))
        XCTAssertEqual(progress, 0.0, accuracy: 1e-6)
    }
    
    func test_activityNotificationPosted_eachTick_withCorrectFlag() {
        let nowHour = Calendar.current.component(.hour, from: Date())
        let (serviceActive, _, _) = makeService(start: nowHour - 0, end: nowHour + 1)
        let (serviceInactive, _, _) = makeService(start: nowHour + 2, end: nowHour + 3)
        
        var activeFlag: Bool?
        var inactiveFlag: Bool?
        let exp1 = expectation(description: "active notif")
        let exp2 = expectation(description: "inactive notif")
        let token1 = NotificationCenter.default.addObserver(forName: .reportPeriodActivityChanged, object: serviceActive, queue: .main) { note in
            activeFlag = note.userInfo?["isActive"] as? Bool
            exp1.fulfill()
        }
        let token2 = NotificationCenter.default.addObserver(forName: .reportPeriodActivityChanged, object: serviceInactive, queue: .main) { note in
            inactiveFlag = note.userInfo?["isActive"] as? Bool
            exp2.fulfill()
        }
        
        serviceActive.updateTimeLeft()
        serviceInactive.updateTimeLeft()
        wait(for: [exp1, exp2], timeout: 1.0)
        
        XCTAssertEqual(activeFlag, true)
        XCTAssertEqual(inactiveFlag, false)
        
        NotificationCenter.default.removeObserver(token1)
        NotificationCenter.default.removeObserver(token2)
    }
}
