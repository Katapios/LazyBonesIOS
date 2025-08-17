import XCTest

final class TelegramPublishRegressionTests: XCTestCase {
    /// Проверяет, что в DailyPlanningFormView.publishCustomReportToTelegram()
    /// вызывается store.load() перед первой проверкой isEvaluated.
    func test_PublishCustomReport_HasStoreLoadBeforeIsEvaluatedCheck() throws {
        // Попытка получить путь к корню проекта через переменную окружения SRCROOT
        let env = ProcessInfo.processInfo.environment
        guard let srcRoot = env["SRCROOT"] ?? env["PROJECT_DIR"] else {
            XCTFail("SRCROOT/PROJECT_DIR env not found; cannot locate source file")
            return
        }
        let filePath = srcRoot + "/LazyBones/Views/Forms/DailyPlanningFormView.swift"
        let url = URL(fileURLWithPath: filePath)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            XCTFail("Failed to read DailyPlanningFormView.swift at path: \(filePath). Error: \(error)")
            return
        }
        guard let content = String(data: data, encoding: .utf8) else {
            XCTFail("Unable to decode file content as UTF-8")
            return
        }
        // Находим диапазон функции publishCustomReportToTelegram
        guard let funcRange = content.range(of: "func publishCustomReportToTelegram()") else {
            XCTFail("publishCustomReportToTelegram() not found in DailyPlanningFormView.swift")
            return
        }
        let tail = String(content[funcRange.lowerBound...])
        // Ищем первое вхождение нужных подстрок
        guard let loadRange = tail.range(of: "store.load()") else {
            XCTFail("store.load() call not found inside publishCustomReportToTelegram()")
            return
        }
        guard let evalCheckRange = tail.range(of: "isEvaluated") else {
            XCTFail("isEvaluated check not found inside publishCustomReportToTelegram()")
            return
        }
        // Проверяем, что load() встречается раньше, чем проверка isEvaluated
        XCTAssertTrue(loadRange.lowerBound < evalCheckRange.lowerBound,
                      "store.load() must appear before isEvaluated check in publishCustomReportToTelegram()")
    }
}
