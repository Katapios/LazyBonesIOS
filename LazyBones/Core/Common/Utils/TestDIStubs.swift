import Foundation
import Combine

// MARK: - Test Stubs

final class TelegramServiceStub: TelegramServiceProtocol {
    func sendMessage(_ text: String, to chatId: String) async throws {}
    func sendDocument(_ fileURL: URL, caption: String?, to chatId: String) async throws {}
    func sendVoice(_ fileURL: URL, caption: String?, to chatId: String) async throws {}
    func getUpdates(offset: Int?) async throws -> [TelegramUpdate] { return [] }
    func getMe() async throws -> TelegramUser { TelegramUser(id: 0, isBot: true, firstName: "stub", lastName: nil, username: "stub") }
    func downloadFile(_ fileId: String) async throws -> Data { Data() }
}

final class PostTelegramServiceStub: PostTelegramServiceProtocol {
    func sendToTelegram(text: String, completion: @escaping (Bool) -> Void) { completion(true) }
    func performAutoSendReport(completion: (() -> Void)?) { completion?() }
    func autoSendAllReportsForToday() {}
    func sendUnsentReportsFromPreviousDays() {}
}

final class NotificationManagerServiceStub: NotificationManagerServiceProtocol {
    @Published var notificationsEnabled: Bool = false
    @Published var notificationIntervalHours: Int = 1
    @Published var notificationStartHour: Int = 8
    @Published var notificationEndHour: Int = 22
    @Published var notificationMode: NotificationMode = .hourly

    func saveNotificationSettings() {}
    func loadNotificationSettings() {}
    func requestNotificationPermissionAndSchedule() {}
    func scheduleNotifications() {}
    func cancelAllNotifications() {}
    func scheduleNotificationsIfNeeded() {}
    func notificationScheduleForToday() -> String? { nil }
}

final class AutoSendServiceStub: AutoSendServiceProtocol {
    @Published var autoSendEnabled: Bool = false
    @Published var autoSendTime: Date = Date()
    @Published var lastAutoSendStatus: String? = nil

    func loadAutoSendSettings() {}
    func saveAutoSendSettings() {}
    func scheduleAutoSendIfNeeded() {}
    func performAutoSendReport() {}
    func performAutoSendReport(completion: (() -> Void)?) { completion?() }
    func autoSendAllReportsForToday(completion: (() -> Void)?) { completion?() }
}

@MainActor
final class TagProviderStub: TagProviderProtocol {
    var goodTags: [String] { [] }
    var badTags: [String] { [] }
    func refresh() async {}
}


