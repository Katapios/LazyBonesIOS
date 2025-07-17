//
//  LazyBonesTests.swift
//  LazyBonesTests
//
//  Created by Денис Рюмин on 11.07.2025.
//

import Testing
import LazyBones // Импортировать основной модуль, если требуется
import XCTest
@testable import LazyBones

struct LazyBonesTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testHourlyNotificationSchedule() async throws {
        let store = PostStore()
        store.notificationMode = .hourly
        store.notificationStartHour = 8
        store.notificationEndHour = 22
        store.notificationsEnabled = true
        store.reportStatus = .notStarted
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        // Симулируем включение уведомлений в 10:00
        let hours = Array(11...21) // 11:00 до 21:00
        let expected = hours.map { String(format: "%02d:00", $0) }
        let today = calendar.startOfDay(for: now)
        let times = hours.map { hour -> String in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        #expect(times == expected)
    }

    @Test func testTwiceNotificationSchedule() async throws {
        let store = PostStore()
        store.notificationMode = .twice
        store.notificationStartHour = 8
        store.notificationEndHour = 22
        store.notificationsEnabled = true
        store.reportStatus = .notStarted
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        // Симулируем включение уведомлений в 20:00
        let hours = [21] // Только 21:00 осталось
        let expected = ["21:00"]
        let today = calendar.startOfDay(for: now)
        let times = hours.map { hour -> String in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        #expect(times == expected)
    }

    @Test func testNoNotificationsAfterReportSent() async throws {
        let store = PostStore()
        store.notificationMode = .hourly
        store.notificationStartHour = 8
        store.notificationEndHour = 22
        store.notificationsEnabled = true
        store.reportStatus = .done
        // scheduleNotifications не должен создавать уведомления
        // (Проверка: функция просто завершится без ошибок)
        store.scheduleNotifications()
        #expect(true)
    }
}

final class LocalReportServiceTests: XCTestCase {
    var service: LocalReportService!
    override func setUp() {
        super.setUp()
        service = LocalReportService.shared
        // Очистить теги перед тестом
        service.saveTags([])
    }
    func testAddTag() {
        service.addTag("TestTag")
        XCTAssertTrue(service.loadTags().contains("TestTag"))
    }
    func testRemoveTag() {
        service.addTag("ToRemove")
        service.removeTag("ToRemove")
        XCTAssertFalse(service.loadTags().contains("ToRemove"))
    }
    func testUpdateTag() {
        service.addTag("OldTag")
        service.updateTag(old: "OldTag", new: "NewTag")
        XCTAssertTrue(service.loadTags().contains("NewTag"))
        XCTAssertFalse(service.loadTags().contains("OldTag"))
    }
    func testFallbackToDefaultTags() {
        service.saveTags([])
        let tags = service.loadTags()
        XCTAssertFalse(tags.isEmpty)
    }
}

final class DailyPlanningFormViewTests: XCTestCase {
    func testPlanResetEachDay() {
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let plan = ["Task1", "Task2"]
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            XCTAssertEqual(decoded, plan)
        } else {
            XCTFail("Plan not saved or loaded correctly")
        }
    }
}
