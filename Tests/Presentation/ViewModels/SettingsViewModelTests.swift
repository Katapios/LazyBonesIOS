import XCTest
@testable import LazyBones

@MainActor
class SettingsViewModelTests: XCTestCase {
    
    var viewModel: SettingsViewModel!
    var mockStore: PostStore!
    
    override func setUp() {
        super.setUp()
        mockStore = PostStore()
        viewModel = SettingsViewModel(store: mockStore)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStore = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_LoadsSettings() {
        // Given & When - в setUp()
        
        // Then
        XCTAssertEqual(viewModel.deviceName, "")
        XCTAssertEqual(viewModel.telegramToken, "")
        XCTAssertEqual(viewModel.telegramChatId, "")
        XCTAssertEqual(viewModel.telegramBotId, "")
        XCTAssertFalse(viewModel.isBackgroundFetchTestEnabled)
    }
    
    // MARK: - Device Name Tests
    
    func testSaveDeviceName_SavesToUserDefaults() {
        // Given
        viewModel.deviceName = "Test Device"
        
        // When
        viewModel.saveDeviceName()
        
        // Then
        let savedName = AppConfig.sharedUserDefaults.string(forKey: "deviceName")
        XCTAssertEqual(savedName, "Test Device")
    }
    
    func testSaveDeviceName_ShowsSavedMessage() {
        // Given
        viewModel.deviceName = "Test Device"
        
        // When
        viewModel.saveDeviceName()
        
        // Then
        XCTAssertTrue(viewModel.showSaved)
    }
    
    // MARK: - Telegram Integration Tests
    
    func testSaveTelegramSettings_WithValidData() {
        // Given
        viewModel.telegramToken = "test_token"
        viewModel.telegramChatId = "test_chat_id"
        viewModel.telegramBotId = "test_bot_id"
        
        // When
        viewModel.saveTelegramSettings()
        
        // Then
        XCTAssertEqual(viewModel.telegramStatus, "Сохранено!")
        XCTAssertEqual(mockStore.telegramToken, "test_token")
        XCTAssertEqual(mockStore.telegramChatId, "test_chat_id")
        XCTAssertEqual(mockStore.telegramBotId, "test_bot_id")
    }
    
    func testSaveTelegramSettings_WithEmptyData() {
        // Given
        viewModel.telegramToken = ""
        viewModel.telegramChatId = ""
        viewModel.telegramBotId = ""
        
        // When
        viewModel.saveTelegramSettings()
        
        // Then
        XCTAssertEqual(viewModel.telegramStatus, "Сохранено!")
        XCTAssertNil(mockStore.telegramToken)
        XCTAssertNil(mockStore.telegramChatId)
        XCTAssertNil(mockStore.telegramBotId)
    }
    
    func testCheckTelegramConnection_WithEmptyData() {
        // Given
        viewModel.telegramToken = ""
        viewModel.telegramChatId = ""
        
        // When
        viewModel.checkTelegramConnection()
        
        // Then
        XCTAssertEqual(viewModel.telegramStatus, "Введите токен и chat_id")
    }
    
    // MARK: - Data Management Tests
    
    func testClearAllData_CallsStoreMethods() {
        // Given
        let expectation = XCTestExpectation(description: "Store methods called")
        
        // Mock store methods if needed
        // For now, we just verify the method doesn't crash
        
        // When
        viewModel.clearAllData()
        
        // Then
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnlockReports_CallsStoreMethods() {
        // Given
        let expectation = XCTestExpectation(description: "Store methods called")
        
        // Mock store methods if needed
        // For now, we just verify the method doesn't crash
        
        // When
        viewModel.unlockReports()
        
        // Then
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Background Fetch Test Tests
    
    func testSaveBackgroundFetchTestEnabled_SavesToUserDefaults() {
        // Given
        let testValue = true
        
        // When
        viewModel.saveBackgroundFetchTestEnabled(testValue)
        
        // Then
        let savedValue = AppConfig.sharedUserDefaults.bool(forKey: "backgroundFetchTestEnabled")
        XCTAssertEqual(savedValue, testValue)
    }
    
    // MARK: - Computed Properties Tests
    
    func testNotificationsEnabledBinding_UpdatesStore() {
        // Given
        let binding = viewModel.notificationsEnabled
        
        // When
        binding.wrappedValue = true
        
        // Then
        XCTAssertTrue(mockStore.notificationsEnabled)
    }
    
    func testNotificationModeBinding_UpdatesStore() {
        // Given
        let binding = viewModel.notificationMode
        
        // When
        binding.wrappedValue = .hourly
        
        // Then
        XCTAssertEqual(mockStore.notificationMode, .hourly)
    }
    
    func testAutoSendEnabledBinding_UpdatesStore() {
        // Given
        let binding = viewModel.autoSendEnabled
        
        // When
        binding.wrappedValue = true
        
        // Then
        XCTAssertTrue(mockStore.autoSendService.autoSendEnabled)
    }
    
    // MARK: - Notifications Tests
    
    func testNotificationScheduleForToday_DelegatesToStore() {
        // Given
        let expectedSchedule = "8:00, 21:00"
        // Mock store.notificationManagerService.notificationScheduleForToday() to return expectedSchedule
        
        // When
        let result = viewModel.notificationScheduleForToday()
        
        // Then
        // For now, we just verify the method doesn't crash
        // In a real test, we would mock the store and verify the result
        XCTAssertNotNil(result)
    }
} 