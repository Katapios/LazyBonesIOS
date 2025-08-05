import Foundation

/// Протокол репозитория для работы с iCloud отчетами
protocol ICloudReportRepositoryProtocol {
    
    /// Сохранить контент в iCloud файл
    /// - Parameters:
    ///   - content: Контент для сохранения
    ///   - append: Если true, дописывает к существующему файлу, иначе перезаписывает
    /// - Returns: URL сохраненного файла
    func saveToICloud(content: String, append: Bool) async throws -> URL
    
    /// Читать контент из iCloud файла
    /// - Returns: Содержимое файла
    func readFromICloud() async throws -> String
    
    /// Проверить доступность iCloud
    /// - Returns: true если iCloud доступен
    func isICloudAvailable() async -> Bool
    
    /// Получить URL файла отчетов в iCloud
    /// - Returns: URL файла или nil если файл не существует
    func getICloudFileURL() async -> URL?
    
    /// Удалить файл отчетов из iCloud
    func deleteICloudFile() async throws
    
    /// Получить размер файла отчетов
    /// - Returns: Размер файла в байтах или nil если файл не существует
    func getFileSize() async -> Int64?
    
    /// Получить информацию о расположении файла
    /// - Returns: Строка с информацией о файле
    func getFileLocationInfo() -> String
    
    /// Запросить доступ к iCloud Drive
    /// - Returns: true если доступ получен
    func requestICloudAccess() async -> Bool
    
    /// Запросить разрешения на доступ к файлам
    /// - Returns: true если разрешения получены
    func requestFileAccessPermissions() async -> Bool
} 