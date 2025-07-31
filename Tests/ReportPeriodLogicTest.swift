import XCTest
@testable import LazyBones

class ReportPeriodLogicTest: XCTestCase {
    
    func testReportPeriodActive() {
        let calendar = Calendar.current
        let now = Date()
        
        // Тестируем логику активного периода
        let startHour = 8
        let endHour = 22
        
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now)!
        
        let isActive = now >= start && now < end
        
        print("Текущее время: \(now)")
        print("Начало периода: \(start)")
        print("Конец периода: \(end)")
        print("Период активен: \(isActive)")
        
        // Проверяем, что логика работает
        let currentHour = calendar.component(.hour, from: now)
        if currentHour >= startHour && currentHour < endHour {
            XCTAssertTrue(isActive, "Период должен быть активен в рабочее время")
        } else {
            XCTAssertFalse(isActive, "Период не должен быть активен вне рабочего времени")
        }
    }
    
    func testReportStatusLogic() {
        // Тестируем логику статусов
        let statuses: [ReportStatus] = [.notStarted, .inProgress, .done, .notCreated, .notSent, .sent]
        
        for status in statuses {
            print("Статус: \(status) - \(status.displayName)")
            
            switch status {
            case .notStarted:
                XCTAssertEqual(status.displayName, "Заполни отчет")
            case .inProgress:
                XCTAssertEqual(status.displayName, "Отчет заполняется...")
            case .done:
                XCTAssertEqual(status.displayName, "Завершен")
            case .notCreated:
                XCTAssertEqual(status.displayName, "Отчёт не создан")
            case .notSent:
                XCTAssertEqual(status.displayName, "Отчёт не отправлен")
            case .sent:
                XCTAssertEqual(status.displayName, "Отчет отправлен")
            }
        }
    }
} 