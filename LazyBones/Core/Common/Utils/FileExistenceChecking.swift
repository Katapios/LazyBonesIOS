import Foundation

protocol FileExistenceChecking {
    func exists(atPath path: String) -> Bool
}

struct DefaultFileExistenceChecker: FileExistenceChecking {
    func exists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
}
