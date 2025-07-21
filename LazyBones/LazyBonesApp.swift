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
        registerBGTask()
        scheduleSendReportBGTask()
    }
}

private func registerBGTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.katapios.LazyBones.sendReport", using: nil) { task in
        handleSendReportTask(task: task as! BGAppRefreshTask)
    }
}

private func handleSendReportTask(task: BGAppRefreshTask) {
    let store = PostStore.shared
    store.performAutoSendReport()
    scheduleSendReportBGTask()
    task.setTaskCompleted(success: true)
}

private func scheduleSendReportBGTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.katapios.LazyBones.sendReport")
    request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("[BGTask] Не удалось запланировать задачу: \(error)")
    }
}
