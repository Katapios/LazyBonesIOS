import Foundation

/// Входные данные для обновления статуса
struct UpdateStatusInput {
    let forceUnlock: Bool?
    let checkNewDay: Bool
    
    init(forceUnlock: Bool? = nil, checkNewDay: Bool = true) {
        self.forceUnlock = forceUnlock
        self.checkNewDay = checkNewDay
    }
}

/// Ошибки обновления статуса
enum UpdateStatusError: Error, LocalizedError {
    case repositoryError(Error)
    case invalidStatus
    
    var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Ошибка обновления: \(error.localizedDescription)"
        case .invalidStatus:
            return "Некорректный статус"
        }
    }
}

/// Use Case для обновления статуса отчетов
protocol UpdateStatusUseCaseProtocol: UseCaseProtocol where
    Input == UpdateStatusInput,
    Output == ReportStatus,
    ErrorType == UpdateStatusError {
}

/// Реализация Use Case для обновления статуса отчетов
class UpdateStatusUseCase: UpdateStatusUseCaseProtocol {
    
    private let postRepository: PostRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(
        postRepository: PostRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.postRepository = postRepository
        self.settingsRepository = settingsRepository
    }
    
    func execute(input: UpdateStatusInput) async throws -> ReportStatus {
        do {
            // Проверяем новый день
            if input.checkNewDay {
                try await checkForNewDay()
            }
            
            // Обновляем forceUnlock если передан
            if let forceUnlock = input.forceUnlock {
                try await settingsRepository.saveForceUnlock(forceUnlock)
            }
            
            // Получаем текущий статус
            let currentStatus = try await settingsRepository.loadReportStatus()
            
            // Получаем отчеты за сегодня
            let todayPosts = try await postRepository.fetch(for: Calendar.current.startOfDay(for: Date()))
            
            // Определяем новый статус
            let newStatus = calculateNewStatus(
                currentStatus: currentStatus,
                todayPosts: todayPosts,
                forceUnlock: input.forceUnlock ?? false
            )
            
            // Сохраняем новый статус
            try await settingsRepository.saveReportStatus(newStatus)
            
            return newStatus
        } catch {
            throw UpdateStatusError.repositoryError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkForNewDay() async throws {
        // Получаем сохраненный день
        let currentStatus = try await settingsRepository.loadReportStatus()
        
        // Если наступил новый день, сбрасываем статус
        if shouldResetOnNewDay(currentStatus) {
            try await settingsRepository.saveReportStatus(.notStarted)
            
            // Сбрасываем forceUnlock для нового дня
            let forceUnlock = try await settingsRepository.loadForceUnlock()
            if forceUnlock {
                try await settingsRepository.saveForceUnlock(false)
            }
        }
    }
    
    private func calculateNewStatus(
        currentStatus: ReportStatus,
        todayPosts: [DomainPost],
        forceUnlock: Bool
    ) -> ReportStatus {
        // Если включен forceUnlock, возвращаем notStarted
        if forceUnlock {
            return .notStarted
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Проверяем активность периода (8:00 - 22:00)
        let startHour = 8
        let endHour = 22
        let currentHour = calendar.component(.hour, from: now)
        let isPeriodActive = currentHour >= startHour && currentHour < endHour
        
        // Ищем обычный отчет за сегодня
        let regularPost = todayPosts.first { 
            $0.type == .regular && calendar.isDate($0.date, inSameDayAs: calendar.startOfDay(for: now)) 
        }
        
        // Определяем статус
        if regularPost == nil {
            return isPeriodActive ? .notStarted : .notCreated
        } else if regularPost!.published {
            return .sent
        } else {
            return isPeriodActive ? .inProgress : .notSent
        }
    }
    
    private func shouldResetOnNewDay(_ status: ReportStatus) -> Bool {
        // Сбрасываем статус на новый день для определенных статусов
        switch status {
        case .sent, .notSent:
            return true
        case .notStarted, .inProgress, .notCreated:
            return false
        }
    }
} 