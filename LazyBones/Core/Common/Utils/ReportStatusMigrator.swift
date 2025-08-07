import Foundation

/// Утилита для миграции статусов отчетов с .done на .sent
class ReportStatusMigrator {
    
    /// Мигрирует статус с .done на .sent для обратной совместимости
    static func migrateStatus(_ rawValue: String) -> ReportStatus {
        if rawValue == "done" {
            return .sent
        }
        return ReportStatus(rawValue: rawValue) ?? .notStarted
    }
    
    /// Мигрирует массив отчетов, заменяя .done на .sent
    static func migratePosts(_ posts: [Post]) -> [Post] {
        return posts.map { post in
            let updatedPost = post
            // Если есть какие-то внутренние статусы в Post, их тоже можно мигрировать
            return updatedPost
        }
    }
    
    /// Проверяет, нужна ли миграция для сохраненного статуса
    static func needsMigration(savedStatus: String) -> Bool {
        return savedStatus == "done"
    }
    
    /// Выполняет полную миграцию статусов в UserDefaults
    static func performFullMigration() {
        let userDefaults = UserDefaults.standard
        
        // Мигрируем сохраненный статус отчета
        if let savedStatusString = userDefaults.string(forKey: "reportStatus"),
           needsMigration(savedStatus: savedStatusString) {
            userDefaults.set("sent", forKey: "reportStatus")
            Logger.info("Migrated report status from 'done' to 'sent'", log: Logger.general)
        }
        
        // Мигрируем статусы в сохраненных отчетах
        if let postsData = userDefaults.data(forKey: "posts") {
            do {
                let posts = try JSONDecoder().decode([Post].self, from: postsData)
                let migratedPosts = migratePosts(posts)
                let migratedData = try JSONEncoder().encode(migratedPosts)
                userDefaults.set(migratedData, forKey: "posts")
                Logger.info("Migrated \(posts.count) posts status references", log: Logger.general)
            } catch {
                Logger.error("Failed to migrate posts: \(error)", log: Logger.general)
            }
        }
    }
}
