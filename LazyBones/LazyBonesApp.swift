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
    logBGTaskEvent("Handling BGTask: performAutoSendReport")
    let store = PostStore.shared
    store.performAutoSendReport()
    logBGTaskEvent("Rescheduling BGTask after execution")
    scheduleSendReportBGTask()
    task.setTaskCompleted(success: true)
}

private func scheduleSendReportBGTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.katapios.LazyBones.sendReport")
    request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
    do {
        try BGTaskScheduler.shared.submit(request)
        logBGTaskEvent("BGTask scheduled for +1 hour")
    } catch {
        logBGTaskEvent("Failed to schedule BGTask: \(error)")
        print("[BGTask] Не удалось запланировать задачу: \(error)")
    }
}
