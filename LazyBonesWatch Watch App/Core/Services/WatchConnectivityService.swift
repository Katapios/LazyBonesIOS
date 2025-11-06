import Foundation
import WatchConnectivity

/// Сервис для получения данных от iPhone через WatchConnectivity
@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()
    
    private var session: WCSession?
    var onDataReceived: ((WatchReportData) -> Void)?
    
    private override init() {
        super.init()
        #if DEBUG
        print("[WatchConnectivity] WatchConnectivityService initialized")
        #endif
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            #if DEBUG
            print("[WatchConnectivity] WCSession not supported on Watch")
            #endif
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func requestUpdate() {
        guard let session = session, session.isReachable else {
            #if DEBUG
            print("[WatchConnectivity] iPhone not reachable, cannot request update")
            #endif
            return
        }
        
        let message: [String: Any] = ["type": "requestUpdate"]
        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor [weak self] in
                if let type = response["type"] as? String, type == "reportData",
                   let data = response["data"] as? Data {
                    do {
                        let decoder = JSONDecoder()
                        let reportData = try decoder.decode(WatchReportData.self, from: data)
                        self?.onDataReceived?(reportData)
                    } catch {
                        #if DEBUG
                        print("[WatchConnectivity] Error decoding report data from reply: \(error)")
                        #endif
                    }
                }
            }
        }) { error in
            #if DEBUG
            print("[WatchConnectivity] Error requesting update: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                #if DEBUG
                print("[WatchConnectivity] Activation failed: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("[WatchConnectivity] Session activated with state: \(activationState.rawValue)")
                #endif
                // Запрашиваем обновление данных при активации, если сессия доступна
                if session.isReachable {
                    requestUpdate()
                }
            }
        }
    }
    
    // На watchOS эти методы недоступны, они доступны только на iOS
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("[WatchConnectivity] Session became inactive")
        #endif
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
        }
    }
    #endif
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            handleMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    @MainActor
    private func handleMessage(_ message: [String : Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "reportData":
            if let data = message["data"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let reportData = try decoder.decode(WatchReportData.self, from: data)
                    onDataReceived?(reportData)
                } catch {
                    #if DEBUG
                    print("[WatchConnectivity] Error decoding report data: \(error)")
                    #endif
                }
            }
        default:
            break
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            handleMessage(applicationContext)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        Task { @MainActor in
            handleMessage(userInfo)
        }
    }
}

