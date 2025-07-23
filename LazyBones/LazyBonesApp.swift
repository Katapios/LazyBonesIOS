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
    // Если включён тест — каждые 30 минут, иначе раз в час
    let ud = UserDefaults(suiteName: "group.com.katapios.LazyBones")
    let isBFTest = ud?.bool(forKey: "backgroundFetchTestEnabled") ?? false
    let interval: TimeInterval = isBFTest ? 30 * 60 : 60 * 60
    request.earliestBeginDate = Date().addingTimeInterval(interval)
    do {
        try BGTaskScheduler.shared.submit(request)
        logBGTaskEvent("BGTask scheduled for +\(interval/60) min")
    } catch {
        logBGTaskEvent("Failed to schedule BGTask: \(error)")
        print("[BGTask] Не удалось запланировать задачу: \(error)")
    }
}
