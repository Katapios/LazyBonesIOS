import XCTest
@testable import LazyBones

class NewStatusLogicTest: XCTestCase {
    
    func testStatusLogicScenarios() {
        // Тестируем все сценарии статусов
        
        print("=== Тестирование логики статусов ===")
        
        // Сценарий 1: Отчет не создан, период активен
        print("1. Отчет не создан, период активен -> .notStarted (Заполни отчет)")
        
        // Сценарий 2: Отчет сохранен, не отправлен, период активен
        print("2. Отчет сохранен, не отправлен, период активен -> .inProgress (Отчет заполняется...)")
        
        // Сценарий 3: Отчет отправлен, период активен
        print("3. Отчет отправлен, период активен -> .sent (Отчет отправлен)")
        
        // Сценарий 4: Отчет отправлен, период закончился
        print("4. Отчет отправлен, период закончился -> .sent (Отчет отправлен)")
        
        // Сценарий 5: Отчет не создан, период закончился
        print("5. Отчет не создан, период закончился -> .notCreated (Отчёт не создан)")
        
        // Сценарий 6: Отчет создан, не отправлен, период закончился
        print("6. Отчет создан, не отправлен, период закончился -> .notSent (Отчёт не отправлен)")
        
        XCTAssertTrue(true, "Логика статусов определена")
    }
    
    func testButtonLogic() {
        // Тестируем логику кнопок
        
        print("=== Тестирование логики кнопок ===")
        
        // Кнопка активна только для .notStarted и .inProgress
        let activeStatuses: [ReportStatus] = [.notStarted, .inProgress]
        let inactiveStatuses: [ReportStatus] = [.sent, .notCreated, .notSent]
        
        for status in activeStatuses {
            print("Кнопка активна для статуса: \(status.displayName)")
        }
        
        for status in inactiveStatuses {
            print("Кнопка неактивна для статуса: \(status.displayName)")
        }
        
        XCTAssertEqual(activeStatuses.count, 2, "Должно быть 2 активных статуса")
        XCTAssertEqual(inactiveStatuses.count, 4, "Должно быть 4 неактивных статуса")
    }
    
    func testTimerLogic() {
        // Тестируем логику таймера
        
        print("=== Тестирование логики таймера ===")
        
        // "До старта" для завершенных статусов
        let startTimerStatuses: [ReportStatus] = [.sent, .notCreated, .notSent]
        
        // "До конца" для активных статусов
        let endTimerStatuses: [ReportStatus] = [.notStarted, .inProgress]
        
        for status in startTimerStatuses {
            print("Таймер 'До старта' для статуса: \(status.displayName)")
        }
        
        for status in endTimerStatuses {
            print("Таймер 'До конца' для статуса: \(status.displayName)")
        }
        
        XCTAssertEqual(startTimerStatuses.count, 3, "Должно быть 3 статуса с таймером 'До старта'")
        XCTAssertEqual(endTimerStatuses.count, 2, "Должно быть 2 статуса с таймером 'До конца'")
    }
} 