//
//  LazyBonesApp.swift
//  LazyBones
//
//  Created by Денис Рюмин on 10.07.2025.
//

import SwiftUI
import BackgroundTasks

@main
struct LazyBonesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        logBGTaskEvent("App init: Registering BGTask")
        registerBGTask()
        logBGTaskEvent("App init: Scheduling BGTask")
        scheduleSendReportBGTask()
    }
}

private func registerBGTask() {
    logBGTaskEvent("Registering BGTaskScheduler for com.katapios.LazyBones.sendReport")
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.katapios.LazyBones.sendReport", using: nil) { task in
        logBGTaskEvent("BGTask triggered: com.katapios.LazyBones.sendReport")
        handleSendReportTask(task: task as! BGAppRefreshTask)
    }
}

private func handleSendReportTask(task: BGAppRefreshTask) {
    logBGTaskEvent("Handling BGTask: autoSendAllReportsForToday")
    let store = PostStore.shared
    let ud = UserDefaults(suiteName: "group.com.katapios.LazyBones")
    let isAutoSend = ud?.bool(forKey: "autoSendToTelegram") ?? false
    if isAutoSend {
        store.autoSendAllReportsForToday {
            logBGTaskEvent("AutoSend: reports sent")
        }
    } else {
        logBGTaskEvent("AutoSend: disabled")
    }
    logBGTaskEvent("Rescheduling BGTask after execution")
    scheduleSendReportBGTask()
    task.setTaskCompleted(success: true)
}

private func scheduleSendReportBGTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.katapios.LazyBones.sendReport")
    let calendar = Calendar.current
    let now = Date()
    let today22 = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
    let tomorrow8 = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!)!
    var earliest: Date
    if now < today22 {
        earliest = today22
    } else if now >= today22 && now < tomorrow8 {
        earliest = now
    } else {
        // после 8 утра — планируем на следующий день в 22:00
        let next22 = calendar.date(byAdding: .day, value: 1, to: today22)!
        earliest = next22
    }
    request.earliestBeginDate = earliest
    do {
        try BGTaskScheduler.shared.submit(request)
        logBGTaskEvent("BGTask scheduled for: \(earliest)")
    } catch {
        logBGTaskEvent("Failed to schedule BGTask: \(error)")
        print("[BGTask] Не удалось запланировать задачу: \(error)")
    }
}
