# Settings Module Migration to Clean Architecture

## Summary
- SettingsView now uses `SettingsViewModelNew` (presentation layer) with protocol-driven dependencies via `DependencyContainer`.
- Legacy `SettingsViewModel` (PostStore-based) and its tests were removed.
- Notification persistence is unified through `UserDefaultsManagerProtocol` used by `NotificationManagerService`.
- Telegram connectivity is handled by `TelegramIntegrationService`.
- Force unlock flow goes through `ReportStatusManagerProtocol` with `.reportStatusDidChange` notifications for UI updates.
- iCloud export is abstracted behind `ICloudServiceProtocol`.

## Layers and Responsibilities
- Presentation: `SettingsViewModelNew` exposes `State` and handles `Event` to orchestrate services/repositories.
- Domain: Entities like `ReportStatus`; protocols for repositories and services used by VM.
- Data: `SettingsRepository` persists settings to `UserDefaultsManagerProtocol`.
- Infrastructure: `NotificationManagerService`, `TelegramIntegrationService`, `ICloudService`, DI registration.

## Dependency Injection
- All dependencies are resolved via `DependencyContainer.shared` using protocol types:
  - `SettingsRepositoryProtocol`
  - `NotificationManagerServiceType` (protocol)
  - `TelegramIntegrationServiceProtocol`
  - `ReportStatusManagerProtocol`
  - `ICloudServiceProtocol`

## Persistence Keys (UserDefaultsManager)
- notificationsEnabled: Bool
- notificationMode: String ("hourly" | "twice")
- notificationIntervalHours: Int
- notificationStartHour: Int
- notificationEndHour: Int
- telegramToken: String?
- telegramChatId: String?
- telegramBotId: String?
- autoSendToTelegram: Bool
- autoSendTime: Date
- deviceName: String
- forceUnlock: Bool

## Critical Fixes
- Use `UserDefaultsManagerProtocol` in `NotificationManagerService` to avoid mixed UserDefaults instances; call `synchronize()` inside manager.
- In `SettingsRepository`, store Telegram using `saveTelegramSettings(token:chatId:botId:)` instead of manual set/remove.
- After saving Telegram, reinitialize/refresh `TelegramService` via DI when needed.
- Move Telegram connectivity check out of VM into `TelegramIntegrationService`.
- Force unlock resets status to `notStarted` without deleting today report; Main screen updates immediately (legacy `MainViewModel` also listens to `.reportStatusDidChange`).

## Unit Tests
- `Tests/Presentation/ViewModels/SettingsViewModelNewTests.swift` covers:
  - Loading state from repository
  - Notifications: enable/disable, mode changes propagate to service
  - Telegram: saving settings and status message
  - iCloud export happy path
  - Auto-send toggles and time updates
  - Unlock report triggers status manager
- Stability fixes:
  - `NewStatusLogicTest` corrected expectations
  - `ServiceTests` notification scheduling guarded by permission + small delays to avoid UNUserNotificationCenter races

## UI and Navigation
- `SettingsCoordinator` pushes subviews for Telegram and Notifications using `UIHostingController`.
- `SettingsView` retains layout with "Unlock Reports" at the bottom.

## Manual QA Checklist (short)
- Toggle notifications; verify mode hourly/twice; check boundaries start/end hours
- Save Telegram token/chatId/botId; test connection; verify error handling (invalid token/chat_id, network)
- Export to iCloud; verify success message or explicit error
- Unlock reports from settings: status => notStarted, data preserved, main screen edit becomes available immediately

## Next Steps
- Update any remaining Views to new VMs and continue PostStore deprecation
- Keep documentation in sync with future changes
