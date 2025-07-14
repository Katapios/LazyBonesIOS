import Foundation
import WidgetKit

class LocalReportService {
    static let shared = LocalReportService()
    private let userDefaults: UserDefaults?
    private let key = "posts"
    private let reportStatusKey = "reportStatus"
    private let forceUnlockKey = "forceUnlock"
    
    private init() {
        userDefaults = UserDefaults(suiteName: "group.com.katapios.LazyBones")
    }
    
    func loadPosts() -> [Post] {
        guard let data = userDefaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
    
    func savePosts(_ posts: [Post]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        userDefaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func clearPosts() {
        userDefaults?.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getReportStatus() -> ReportStatus {
        if let raw = userDefaults?.string(forKey: reportStatusKey), let status = ReportStatus(rawValue: raw) {
            return status
        }
        return .notStarted
    }
    func saveReportStatus(_ status: ReportStatus) {
        userDefaults?.set(status.rawValue, forKey: reportStatusKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func getForceUnlock() -> Bool {
        userDefaults?.bool(forKey: forceUnlockKey) ?? false
    }
    func saveForceUnlock(_ value: Bool) {
        userDefaults?.set(value, forKey: forceUnlockKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
} 