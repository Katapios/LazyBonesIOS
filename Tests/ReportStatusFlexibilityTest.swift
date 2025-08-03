import XCTest
@testable import LazyBones

class ReportStatusFlexibilityTest: XCTestCase {
    
    var factory: ReportStatusFactory!
    var configProvider: DefaultReportStatusConfigProvider!
    
    override func setUp() {
        super.setUp()
        configProvider = DefaultReportStatusConfigProvider()
        factory = ReportStatusFactory(configProvider: configProvider)
    }
    
    override func tearDown() {
        factory = nil
        configProvider = nil
        super.tearDown()
    }
    
    // MARK: - Тесты конфигурации
    
    func testDefaultConfiguration() {
        let config = configProvider.config
        
        XCTAssertEqual(config.timeSettings.startHour, 8)
        XCTAssertEqual(config.timeSettings.endHour, 22)
        XCTAssertTrue(config.statusSettings.enableForceUnlock)
        XCTAssertTrue(config.statusSettings.autoResetOnNewDay)
        XCTAssertTrue(config.uiSettings.showTimer)
    }
    
    func testCustomConfiguration() {
        let customConfig = ReportStatusConfig(
            timeSettings: ReportStatusConfig.TimeSettings(
                startHour: 9,
                endHour: 18,
                timeZone: .current
            ),
            statusSettings: ReportStatusConfig.StatusSettings(
                enableForceUnlock: false,
                autoResetOnNewDay: false,
                enableNotifications: true
            ),
            uiSettings: ReportStatusConfig.UISettings(
                showTimer: false,
                showProgress: true,
                enableWidgetUpdates: false
            )
        )
        
        let customProvider = DefaultReportStatusConfigProvider(config: customConfig)
        let customFactory = ReportStatusFactory(configProvider: customProvider)
        
        // Проверяем, что конфигурация корректно применяется
        XCTAssertEqual(customConfig.timeSettings.startHour, 9)
        XCTAssertEqual(customConfig.timeSettings.endHour, 18)
        XCTAssertFalse(customConfig.statusSettings.enableForceUnlock)
        XCTAssertFalse(customConfig.statusSettings.autoResetOnNewDay)
        XCTAssertTrue(customConfig.statusSettings.enableNotifications)
        XCTAssertFalse(customConfig.uiSettings.showTimer)
        XCTAssertTrue(customConfig.uiSettings.showProgress)
        XCTAssertFalse(customConfig.uiSettings.enableWidgetUpdates)
        
        // Проверяем, что фабрика создается с кастомной конфигурацией
        XCTAssertNotNil(customFactory)
    }
    
    // MARK: - Тесты фабрики статусов
    
    func testStatusCreation() {
        // Тест 1: Нет отчета, период активен
        let status1 = factory.createStatus(
            hasRegularReport: false,
            isReportPublished: false,
            isPeriodActive: true
        )
        XCTAssertEqual(status1, .notStarted)
        
        // Тест 2: Есть отчет, не отправлен, период активен
        let status2 = factory.createStatus(
            hasRegularReport: true,
            isReportPublished: false,
            isPeriodActive: true
        )
        XCTAssertEqual(status2, .inProgress)
        
        // Тест 3: Есть отчет, отправлен, период активен
        let status3 = factory.createStatus(
            hasRegularReport: true,
            isReportPublished: true,
            isPeriodActive: true
        )
        XCTAssertEqual(status3, .sent)
        
        // Тест 4: Нет отчета, период не активен
        let status4 = factory.createStatus(
            hasRegularReport: false,
            isReportPublished: false,
            isPeriodActive: false
        )
        XCTAssertEqual(status4, .notCreated)
        
        // Тест 5: Есть отчет, не отправлен, период не активен
        let status5 = factory.createStatus(
            hasRegularReport: true,
            isReportPublished: false,
            isPeriodActive: false
        )
        XCTAssertEqual(status5, .notSent)
    }
    
    func testForceUnlock() {
        let status = factory.createStatus(
            hasRegularReport: true,
            isReportPublished: true,
            isPeriodActive: false,
            forceUnlock: true
        )
        XCTAssertEqual(status, .notStarted)
    }
    
    func testStatusResetLogic() {
        XCTAssertTrue(factory.shouldResetOnNewDay(.sent))
        XCTAssertTrue(factory.shouldResetOnNewDay(.notCreated))
        XCTAssertTrue(factory.shouldResetOnNewDay(.notSent))
        XCTAssertTrue(factory.shouldResetOnNewDay(.done))
        XCTAssertFalse(factory.shouldResetOnNewDay(.notStarted))
        XCTAssertFalse(factory.shouldResetOnNewDay(.inProgress))
    }
    
    // MARK: - Тесты UI свойств
    
    func testUIProperties() {
        let statuses: [ReportStatus] = [.notStarted, .inProgress, .sent, .notCreated, .notSent, .done]
        
        for status in statuses {
            // Проверяем, что у каждого статуса есть отображаемое имя
            XCTAssertFalse(status.displayName.isEmpty)
            
            // Проверяем, что у каждого статуса есть цвет
            let color = status.color
            XCTAssertTrue(color == .black || color == .gray)
            
            // Проверяем, что у каждого статуса есть метка таймера
            XCTAssertFalse(status.timerLabel.isEmpty)
            
            // Проверяем, что прогресс в допустимых пределах
            XCTAssertGreaterThanOrEqual(status.progress, 0.0)
            XCTAssertLessThanOrEqual(status.progress, 1.0)
        }
    }
    
    func testEnabledStates() {
        XCTAssertTrue(ReportStatus.notStarted.isEnabled)
        XCTAssertTrue(ReportStatus.inProgress.isEnabled)
        XCTAssertFalse(ReportStatus.sent.isEnabled)
        XCTAssertFalse(ReportStatus.notCreated.isEnabled)
        XCTAssertFalse(ReportStatus.notSent.isEnabled)
        XCTAssertFalse(ReportStatus.done.isEnabled)
    }
    
    // MARK: - Тесты расширяемости
    
    func testStatusEnumExtensibility() {
        // Проверяем, что enum поддерживает Codable
        let status = ReportStatus.sent
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(status)
            let decodedStatus = try decoder.decode(ReportStatus.self, from: data)
            XCTAssertEqual(status, decodedStatus)
        } catch {
            XCTFail("Failed to encode/decode ReportStatus: \(error)")
        }
    }
    
    func testConfigurationExtensibility() {
        // Проверяем, что можно создать конфигурацию с новыми параметрами
        let extendedConfig = ReportStatusConfig(
            timeSettings: ReportStatusConfig.TimeSettings(
                startHour: 6,
                endHour: 23,
                timeZone: .current
            ),
            statusSettings: ReportStatusConfig.StatusSettings(
                enableForceUnlock: true,
                autoResetOnNewDay: true,
                enableNotifications: false
            ),
            uiSettings: ReportStatusConfig.UISettings(
                showTimer: true,
                showProgress: false,
                enableWidgetUpdates: true
            )
        )
        
        XCTAssertNotNil(extendedConfig)
        XCTAssertEqual(extendedConfig.timeSettings.startHour, 6)
        XCTAssertEqual(extendedConfig.timeSettings.endHour, 23)
        XCTAssertFalse(extendedConfig.statusSettings.enableNotifications)
        XCTAssertFalse(extendedConfig.uiSettings.showProgress)
    }
} 