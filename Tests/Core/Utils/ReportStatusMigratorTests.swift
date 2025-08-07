import XCTest
@testable import LazyBones

class ReportStatusMigratorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Очищаем UserDefaults перед каждым тестом
        UserDefaults.standard.removeObject(forKey: "reportStatus")
        UserDefaults.standard.removeObject(forKey: "posts")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "reportStatus")
        UserDefaults.standard.removeObject(forKey: "posts")
        super.tearDown()
    }
    
    // MARK: - Tests for migrateStatus
    
    func testMigrateStatus_WithDoneStatus_ReturnsSent() {
        // When
        let result = ReportStatusMigrator.migrateStatus("done")
        
        // Then
        XCTAssertEqual(result, .sent)
    }
    
    func testMigrateStatus_WithSentStatus_ReturnsSent() {
        // When
        let result = ReportStatusMigrator.migrateStatus("sent")
        
        // Then
        XCTAssertEqual(result, .sent)
    }
    
    func testMigrateStatus_WithValidStatus_ReturnsCorrectStatus() {
        // Given
        let validStatuses = ["notStarted", "inProgress", "notCreated", "notSent"]
        
        for statusString in validStatuses {
            // When
            let result = ReportStatusMigrator.migrateStatus(statusString)
            
            // Then
            XCTAssertEqual(result.rawValue, statusString)
        }
    }
    
    func testMigrateStatus_WithInvalidStatus_ReturnsNotStarted() {
        // When
        let result = ReportStatusMigrator.migrateStatus("invalidStatus")
        
        // Then
        XCTAssertEqual(result, .notStarted)
    }
    
    // MARK: - Tests for needsMigration
    
    func testNeedsMigration_WithDoneStatus_ReturnsTrue() {
        // When
        let result = ReportStatusMigrator.needsMigration(savedStatus: "done")
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testNeedsMigration_WithOtherStatus_ReturnsFalse() {
        // Given
        let otherStatuses = ["sent", "notStarted", "inProgress", "notCreated", "notSent"]
        
        for status in otherStatuses {
            // When
            let result = ReportStatusMigrator.needsMigration(savedStatus: status)
            
            // Then
            XCTAssertFalse(result, "Should return false for status: \(status)")
        }
    }
    
    // MARK: - Tests for performFullMigration
    
    func testPerformFullMigration_WithDoneReportStatus_MigratesToSent() {
        // Given
        UserDefaults.standard.set("done", forKey: "reportStatus")
        
        // When
        ReportStatusMigrator.performFullMigration()
        
        // Then
        let savedStatus = UserDefaults.standard.string(forKey: "reportStatus")
        XCTAssertEqual(savedStatus, "sent")
    }
    
    func testPerformFullMigration_WithValidReportStatus_DoesNotChange() {
        // Given
        UserDefaults.standard.set("inProgress", forKey: "reportStatus")
        
        // When
        ReportStatusMigrator.performFullMigration()
        
        // Then
        let savedStatus = UserDefaults.standard.string(forKey: "reportStatus")
        XCTAssertEqual(savedStatus, "inProgress")
    }
    
    func testPerformFullMigration_WithNoReportStatus_DoesNotCrash() {
        // Given
        // Нет сохраненного статуса
        
        // When
        ReportStatusMigrator.performFullMigration()
        
        // Then
        let savedStatus = UserDefaults.standard.string(forKey: "reportStatus")
        XCTAssertNil(savedStatus)
    }
    
    func testPerformFullMigration_WithPostsData_DoesNotCrash() {
        // Given
        let testPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Test"],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        
        let postsData = try! JSONEncoder().encode([testPost])
        UserDefaults.standard.set(postsData, forKey: "posts")
        
        // When
        ReportStatusMigrator.performFullMigration()
        
        // Then
        // Должно завершиться без ошибок
        let savedData = UserDefaults.standard.data(forKey: "posts")
        XCTAssertNotNil(savedData)
    }
    
    func testPerformFullMigration_WithInvalidPostsData_DoesNotCrash() {
        // Given
        let invalidData = "invalid data".data(using: .utf8)!
        UserDefaults.standard.set(invalidData, forKey: "posts")
        
        // When
        ReportStatusMigrator.performFullMigration()
        
        // Then
        // Должно завершиться без ошибок, данные должны остаться без изменений
        let savedData = UserDefaults.standard.data(forKey: "posts")
        XCTAssertEqual(savedData, invalidData)
    }
}