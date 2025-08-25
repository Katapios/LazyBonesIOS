import Foundation
import UIKit

// MARK: - Publish custom report to Telegram
struct PublishCustomReportInput {
    let date: Date
}

enum PublishCustomReportError: Error, LocalizedError {
    case reportNotFound
    case notEvaluated
    case formatError
    case sendFailed
    
    var errorDescription: String? {
        switch self {
        case .reportNotFound:
            return "Кастомный отчет за выбранную дату не найден"
        case .notEvaluated:
            return "Перед отправкой оцените отчет в разделе Кастомные отчеты"
        case .formatError:
            return "Не удалось сформировать текст для отправки"
        case .sendFailed:
            return "Не удалось отправить сообщение в Telegram"
        }
    }
}

protocol PublishCustomReportUseCaseProtocol: UseCaseProtocol where
    Input == PublishCustomReportInput,
    Output == Bool,
    ErrorType == PublishCustomReportError {}

final class PublishCustomReportUseCase: PublishCustomReportUseCaseProtocol {
    private let postRepository: PostRepositoryProtocol
    private let telegramIntegration: TelegramIntegrationServiceType
    private let postTelegramService: PostTelegramServiceProtocol
    
    init(postRepository: PostRepositoryProtocol,
         telegramIntegration: TelegramIntegrationServiceType,
         postTelegramService: PostTelegramServiceProtocol) {
        self.postRepository = postRepository
        self.telegramIntegration = telegramIntegration
        self.postTelegramService = postTelegramService
    }
    
    func execute(input: PublishCustomReportInput) async throws -> Bool {
        let posts = try await postRepository.fetch(for: input.date)
        guard let custom = posts.first(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: input.date) }) else {
            throw PublishCustomReportError.reportNotFound
        }
        
        guard custom.isEvaluated == true else { throw PublishCustomReportError.notEvaluated }
        
        // Форматируем сообщение и отправляем через PostTelegramService
        let deviceName = UIDevice.current.name
        let message = telegramIntegration.formatCustomReportForTelegram(PostMapper.toDataModel(custom), deviceName: deviceName)
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        postTelegramService.sendToTelegram(text: message) { success in
            result = success
            semaphore.signal()
        }
        semaphore.wait()
        
        if !result { throw PublishCustomReportError.sendFailed }
        return true
    }
}
