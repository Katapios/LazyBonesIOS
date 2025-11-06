import Foundation

final class PlanningLocalDataSource {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults? = nil) {
        // По умолчанию используем app group UserDefaults для совместимости с виджетом
        self.userDefaults = userDefaults ?? AppConfig.sharedUserDefaults
    }
    
    private func key(for date: Date) -> String {
        let dateKey = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        return "plan_" + dateKey
    }
    
    func loadPlan(for date: Date) -> [String] {
        let key = key(for: date)
        guard let data = userDefaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            Logger.warning("Failed to decode plan for key: \(key)", log: Logger.general)
            return []
        }
    }
    
    func savePlan(_ items: [String], for date: Date) {
        let key = key(for: date)
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: key)
        } catch {
            Logger.warning("Failed to encode plan for key: \(key)", log: Logger.general)
        }
    }
}
