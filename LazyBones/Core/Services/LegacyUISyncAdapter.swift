import Foundation
import Combine

protocol LegacyUISyncProtocol {
    func syncReportStatusToLegacyUI()
    func saveForceUnlock(_ value: Bool)
}

final class LegacyUISyncAdapter: LegacyUISyncProtocol {
    func syncReportStatusToLegacyUI() {
        PostStore.shared.updateReportStatus()
        DispatchQueue.main.async {
            PostStore.shared.objectWillChange.send()
        }
    }
    
    func saveForceUnlock(_ value: Bool) {
        LocalReportService.shared.saveForceUnlock(value)
    }
}
