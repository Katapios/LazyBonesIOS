import Foundation
import UIKit
import FileProvider

/// Ошибки работы с iCloud файлами
enum ICloudFileError: LocalizedError {
    case iCloudNotAvailable
    case fileNotFound
    case accessDenied
    case writeError
    case readError
    case directoryCreationFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud недоступен"
        case .fileNotFound:
            return "Файл не найден"
        case .accessDenied:
            return "Нет доступа к файлу"
        case .writeError:
            return "Ошибка записи файла"
        case .readError:
            return "Ошибка чтения файла"
        case .directoryCreationFailed:
            return "Не удалось создать папку"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
}

/// Менеджер для работы с файлами в iCloud Drive
class ICloudFileManager {
    
    private let fileName = "LazyBonesReports.report"
    private let folderName = "LazyBonesReports"
    private var cachedFolderURL: URL?
    
    /// Получить URL папки LazyBonesReports в iCloud Drive
    private func getICloudFolderURL() throws -> URL {
        if let cached = cachedFolderURL {
            // Быстрый возврат из кэша, чтобы не спамить логами
            return cached
        }
        Logger.debug("ICloudFileManager: Starting getICloudFolderURL", log: Logger.general)
        
        // Сначала пробуем получить URL через ubiquity container
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = iCloudURL.appendingPathComponent("Documents")
            let folderURL = documentsURL.appendingPathComponent(folderName)
            
            Logger.debug("ICloudFileManager: Using ubiquity container URL: \(folderURL.path)", log: Logger.general)
            cachedFolderURL = folderURL
            return folderURL
        }
        
        Logger.debug("ICloudFileManager: Ubiquity container not available, trying Documents directory", log: Logger.general)
        
        // Fallback: используем Documents Directory (доступно в iCloud Drive)
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.error("ICloudFileManager: Cannot access Documents directory", log: Logger.general)
            throw ICloudFileError.accessDenied
        }
        
        // На iOS/Desktop контейнер внутри sandbox — пропускаем проверку Desktop на реальных устройствах
        #if targetEnvironment(macCatalyst)
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            Logger.debug("ICloudFileManager: Desktop directory available: \(desktopURL.path)", log: Logger.general)
            let testFileURL = desktopURL.appendingPathComponent(".test")
            do {
                try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: testFileURL)
                Logger.debug("ICloudFileManager: Desktop directory is writable", log: Logger.general)
                let folderURL = desktopURL.appendingPathComponent(folderName)
                Logger.debug("ICloudFileManager: Using Desktop directory for folder: \(folderURL.path)", log: Logger.general)
                cachedFolderURL = folderURL
                return folderURL
            } catch {
                Logger.debug("ICloudFileManager: Desktop not writable: \(error)", log: Logger.general)
            }
        }
        #endif
        
        Logger.debug("ICloudFileManager: Using Documents directory as fallback", log: Logger.general)
        let folderURL = documentsURL.appendingPathComponent(folderName)
        
        Logger.debug("ICloudFileManager: Using Documents directory URL: \(folderURL.path)", log: Logger.general)
        
        // Лишние проверки/вывод содержимого убираем, чтобы не спамить
        cachedFolderURL = folderURL
        return folderURL
    }
    
    /// Получить URL файла отчетов
    private func getReportFileURL() throws -> URL {
        let folderURL = try getICloudFolderURL()
        return folderURL.appendingPathComponent(fileName)
    }
    
    /// Создать папку если она не существует
    private func createFolderIfNeeded() throws {
        Logger.debug("ICloudFileManager: Starting createFolderIfNeeded", log: Logger.general)
        
        let folderURL = try getICloudFolderURL()
        let folderExists = FileManager.default.fileExists(atPath: folderURL.path)
        
        Logger.debug("ICloudFileManager: Folder exists before creation: \(folderExists)", log: Logger.general)
        
        if !folderExists {
            Logger.debug("ICloudFileManager: Creating folder at: \(folderURL.path)", log: Logger.general)
            
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            let folderCreated = FileManager.default.fileExists(atPath: folderURL.path)
            Logger.debug("ICloudFileManager: Folder created successfully: \(folderCreated)", log: Logger.general)
            
            if folderCreated {
                Logger.debug("ICloudFileManager: Created iCloud folder: \(folderURL.path)", log: Logger.general)
            } else {
                Logger.error("ICloudFileManager: Failed to create folder", log: Logger.general)
            }
        } else {
            Logger.debug("ICloudFileManager: Folder already exists: \(folderURL.path)", log: Logger.general)
        }
    }
    
    /// Проверить доступность iCloud
    func isICloudAvailable() -> Bool {
        let hasToken = FileManager.default.ubiquityIdentityToken != nil
        let canAccessICloud = FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
        let canAccessDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first != nil
        
        Logger.debug("ICloudFileManager: iCloud check - hasToken: \(hasToken), canAccessICloud: \(canAccessICloud), canAccessDocuments: \(canAccessDocuments)", log: Logger.general)
        
        if !hasToken {
            Logger.debug("ICloudFileManager: No ubiquityIdentityToken - user not signed into iCloud", log: Logger.general)
        }
        
        if !canAccessICloud && !canAccessDocuments {
            Logger.debug("ICloudFileManager: Cannot access iCloud or Documents directory", log: Logger.general)
        }
        
        // Возвращаем true, если есть хотя бы один способ доступа к файловой системе
        return hasToken && (canAccessICloud || canAccessDocuments)
    }
    
    /// Запросить доступ к iCloud Drive
    func requestICloudAccess() async -> Bool {
        Logger.info("ICloudFileManager: Requesting iCloud access", log: Logger.general)
        
        // Проверяем доступность iCloud
        guard isICloudAvailable() else {
            Logger.error("ICloudFileManager: iCloud not available", log: Logger.general)
            return false
        }
        
        // Пытаемся получить доступ к файловой системе
        do {
            let iCloudURL = try getICloudFolderURL()
            
            // Создаем папку если она не существует
            try createFolderIfNeeded()
            
            // Проверяем, что можем писать в папку
            let testFileURL = iCloudURL.appendingPathComponent(".test")
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            
            Logger.info("ICloudFileManager: Successfully got access to: \(iCloudURL.path)", log: Logger.general)
            return true
        } catch {
            Logger.error("ICloudFileManager: Failed to get access: \(error)", log: Logger.general)
            return false
        }
    }
    
    /// Принудительно запросить разрешения на доступ к файлам
    func requestFileAccessPermissions() async -> Bool {
        Logger.info("ICloudFileManager: Requesting file access permissions", log: Logger.general)
        
        // Пытаемся получить доступ к Documents директории
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.error("ICloudFileManager: Cannot access Documents directory", log: Logger.general)
            return false
        }
        
        // Создаем тестовый файл для запроса разрешений
        let testFileURL = documentsURL.appendingPathComponent("test_permissions.txt")
        
        do {
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            Logger.info("ICloudFileManager: File access permissions granted", log: Logger.general)
            return true
        } catch {
            Logger.error("ICloudFileManager: File access permissions denied: \(error)", log: Logger.general)
            return false
        }
    }
    
    /// Создать файл в более доступном месте для тестирования
    func createTestFileInAccessibleLocation() async -> Bool {
        Logger.info("ICloudFileManager: Creating test file in accessible location", log: Logger.general)
        
        // Попробуем Documents Directory (самый надежный вариант)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let testFileURL = documentsURL.appendingPathComponent("LazyBonesTest.txt")
            
            do {
                try "Test file created by LazyBones app".write(to: testFileURL, atomically: true, encoding: .utf8)
                Logger.info("ICloudFileManager: Created test file in Documents: \(testFileURL.path)", log: Logger.general)
                return true
            } catch {
                Logger.error("ICloudFileManager: Failed to create test file in Documents: \(error)", log: Logger.general)
            }
        }
        
        // Попробуем Desktop Directory
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let testFileURL = desktopURL.appendingPathComponent("LazyBonesTest.txt")
            
            do {
                try "Test file created by LazyBones app".write(to: testFileURL, atomically: true, encoding: .utf8)
                Logger.info("ICloudFileManager: Created test file on Desktop: \(testFileURL.path)", log: Logger.general)
                return true
            } catch {
                Logger.error("ICloudFileManager: Failed to create test file on Desktop: \(error)", log: Logger.general)
            }
        }
        
        // Попробуем Downloads Directory
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            let testFileURL = downloadsURL.appendingPathComponent("LazyBonesTest.txt")
            
            do {
                try "Test file created by LazyBones app".write(to: testFileURL, atomically: true, encoding: .utf8)
                Logger.info("ICloudFileManager: Created test file in Downloads: \(testFileURL.path)", log: Logger.general)
                return true
            } catch {
                Logger.error("ICloudFileManager: Failed to create test file in Downloads: \(error)", log: Logger.general)
            }
        }
        
        Logger.error("ICloudFileManager: Could not create test file in any accessible location", log: Logger.general)
        return false
    }
    
    /// Сохранить контент в файл
    func saveContent(_ content: String, append: Bool = false) async throws -> URL {
        Logger.info("ICloudFileManager: Saving content to iCloud", log: Logger.general)
        
        guard isICloudAvailable() else {
            throw ICloudFileError.iCloudNotAvailable
        }
        
        // Создаем папку если нужно
        try createFolderIfNeeded()
        
        let fileURL = try getReportFileURL()
        let folderURL = try getICloudFolderURL()
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        let folderExists = FileManager.default.fileExists(atPath: folderURL.path)
        
        Logger.info("ICloudFileManager: Target folder: \(folderURL.path)", log: Logger.general)
        Logger.info("ICloudFileManager: Target file: \(fileURL.path)", log: Logger.general)
        Logger.info("ICloudFileManager: Folder exists: \(folderExists)", log: Logger.general)
        Logger.info("ICloudFileManager: File exists: \(fileExists)", log: Logger.general)
        
        var finalContent = content
        
        if append && fileExists {
            // Читаем существующий контент и добавляем новый
            let existingContent = try await readContent()
            finalContent = existingContent + "\n\n" + content
        }
        
        // Сохраняем файл
        do {
            try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.info("ICloudFileManager: Successfully saved content to \(fileURL.path)", log: Logger.general)
            
            // Проверяем результат
            let finalFileExists = FileManager.default.fileExists(atPath: fileURL.path)
            Logger.info("ICloudFileManager: Final file exists: \(finalFileExists)", log: Logger.general)
            
            return fileURL
        } catch {
            Logger.error("ICloudFileManager: Failed to save content: \(error)", log: Logger.general)
            throw ICloudFileError.writeError
        }
    }
    
    /// Читать контент из файла
    func readContent() async throws -> String {
        Logger.info("ICloudFileManager: Reading content from iCloud", log: Logger.general)
        
        guard isICloudAvailable() else {
            throw ICloudFileError.iCloudNotAvailable
        }
        
        let fileURL = try getReportFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ICloudFileError.fileNotFound
        }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            Logger.info("ICloudFileManager: Successfully read content from \(fileURL.path)", log: Logger.general)
            return content
        } catch {
            Logger.error("ICloudFileManager: Failed to read content: \(error)", log: Logger.general)
            throw ICloudFileError.readError
        }
    }
    
    /// Получить URL файла
    func getFileURL() async -> URL? {
        guard isICloudAvailable() else { return nil }
        
        do {
            let fileURL = try getReportFileURL()
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        } catch {
            return nil
        }
    }
    
    /// Получить размер файла
    func getFileSize() async -> Int64? {
        guard let fileURL = await getFileURL() else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Получить информацию о расположении файла
    func getFileLocationInfo() -> String {
        do {
            let folderURL = try getICloudFolderURL()
            let fileURL = try getReportFileURL()
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            let folderExists = FileManager.default.fileExists(atPath: folderURL.path)
            
            var info = "📁 Папка: \(folderURL.path)\n"
            info += "📄 Файл: \(fileURL.path)\n"
            info += "✅ Папка существует: \(folderExists)\n"
            info += "✅ Файл существует: \(fileExists)\n"
            
            // Добавляем инструкции по поиску файла
            info += "\n🔍 Как найти файл в приложении 'Файлы':\n"
            if folderURL.path.contains("Documents") {
                info += "1. Откройте приложение 'Файлы'\n"
                info += "2. Перейдите в 'На устройстве'\n"
                info += "3. Найдите папку 'LazyBones'\n"
                info += "4. Откройте папку 'Documents'\n"
                info += "5. Найдите папку 'LazyBonesReports'\n"
            } else if folderURL.path.contains("Desktop") {
                info += "1. Откройте приложение 'Файлы'\n"
                info += "2. Перейдите в 'На устройстве'\n"
                info += "3. Найдите папку 'LazyBones'\n"
                info += "4. Откройте папку 'Desktop'\n"
                info += "5. Найдите папку 'LazyBonesReports'\n"
            }
            info += "\n"
            
            // Проверяем Documents Directory
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                info += "📂 Documents Directory: \(documentsURL.path)\n"
                
                // Показываем все файлы в Documents
                do {
                    let documentsFiles = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                    info += "📋 Файлы в Documents:\n"
                    for file in documentsFiles {
                        info += "   - \(file.lastPathComponent)\n"
                    }
                } catch {
                    info += "❌ Ошибка чтения Documents: \(error.localizedDescription)\n"
                }
            }
            
            if fileExists {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let size = attributes[.size] as? Int64 ?? 0
                    let creationDate = attributes[.creationDate] as? Date
                    let modificationDate = attributes[.modificationDate] as? Date
                    
                    info += "📊 Размер: \(size) байт\n"
                    if let creationDate = creationDate {
                        info += "📅 Создан: \(creationDate)\n"
                    }
                    if let modificationDate = modificationDate {
                        info += "🔄 Изменен: \(modificationDate)\n"
                    }
                } catch {
                    info += "❌ Ошибка получения атрибутов: \(error.localizedDescription)\n"
                }
            }
            
            return info
        } catch {
            return "❌ Ошибка получения информации: \(error.localizedDescription)"
        }
    }
    
    /// Удалить файл
    func deleteFile() async throws {
        Logger.info("ICloudFileManager: Deleting iCloud file", log: Logger.general)
        
        guard isICloudAvailable() else {
            throw ICloudFileError.iCloudNotAvailable
        }
        
        let fileURL = try getReportFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ICloudFileError.fileNotFound
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            Logger.info("ICloudFileManager: Successfully deleted file", log: Logger.general)
        } catch {
            Logger.error("ICloudFileManager: Failed to delete file: \(error)", log: Logger.general)
            throw ICloudFileError.writeError
        }
    }
} 