import XCTest
@testable import LazyBones

final class PlanningRepositoryTests: XCTestCase {
    private var userDefaults: UserDefaults! = nil
    private var dataSource: PlanningLocalDataSource! = nil
    private var repository: PlanningRepository! = nil
    
    override func setUp() {
        super.setUp()
        // Используем отдельный suite, чтобы не трогать реальное хранилище
        userDefaults = UserDefaults(suiteName: "PlanningRepositoryTests")
        // Очищаем все ключи перед каждым тестом
        userDefaults.removePersistentDomain(forName: "PlanningRepositoryTests")
        dataSource = PlanningLocalDataSource(userDefaults: userDefaults)
        repository = PlanningRepository(dataSource: dataSource)
    }
    
    override func tearDown() {
        repository = nil
        dataSource = nil
        userDefaults.removePersistentDomain(forName: "PlanningRepositoryTests")
        userDefaults = nil
        super.tearDown()
    }
    
    func testSaveAndLoadPlan_ForToday_Roundtrip() {
        // Given
        let today = Date()
        let items = ["A", "B", "C"]
        
        // When
        repository.savePlan(items, for: today)
        let loaded = repository.loadPlan(for: today)
        
        // Then
        XCTAssertEqual(loaded, items)
    }
    
    func testLoadPlan_WhenNoData_ReturnsEmptyArray() {
        // Given
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01
        
        // When
        let loaded = repository.loadPlan(for: date)
        
        // Then
        XCTAssertEqual(loaded, [])
    }
    
    func testKeyCompatibility_StoresDataAtExpectedKey() {
        // Given
        let date = Date()
        let items = ["X"]
        repository.savePlan(items, for: date)
        
        // When: воспроизводим ключ как в реализации
        let key = "plan_" + DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        let data = userDefaults.data(forKey: key)
        
        // Then
        XCTAssertNotNil(data, "Должны сохранять данные по совместимому ключу: \(key)")
        if let data = data, let decoded = try? JSONDecoder().decode([String].self, from: data) {
            XCTAssertEqual(decoded, items)
        } else {
            XCTFail("Не удалось декодировать сохранённые данные по ключу: \(key)")
        }
    }
}
