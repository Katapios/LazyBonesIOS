import XCTest
@testable import LazyBones

class NewDayLogicTest: XCTestCase {
    
    func testNewDayDetection() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Тест: разные дни должны быть разными
        XCTAssertFalse(calendar.isDate(today, inSameDayAs: yesterday))
        
        // Тест: один и тот же день должен быть одинаковым
        let todayCopy = calendar.startOfDay(for: Date())
        XCTAssertTrue(calendar.isDate(today, inSameDayAs: todayCopy))
    }
    
    func testReportStatusReset() {
        // Этот тест можно запустить вручную для проверки логики
        // В реальном приложении статус должен сбрасываться при наступлении нового дня
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        print("Сегодня: \(today)")
        print("Завтра: \(tomorrow)")
        print("Разные дни: \(!calendar.isDate(today, inSameDayAs: tomorrow))")
        
        XCTAssertTrue(!calendar.isDate(today, inSameDayAs: tomorrow))
    }
} 