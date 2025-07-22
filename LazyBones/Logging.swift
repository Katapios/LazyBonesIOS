//
//  Logging.swift
//  LazyBones
//
//  Created for BGTask and auto-send diagnostics
//

import Foundation

func logBGTaskEvent(_ message: String) {
    let log = "[BGTask][\(Date())] \(message)\n"
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("bg_task_log.txt")
        if let data = log.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
} 