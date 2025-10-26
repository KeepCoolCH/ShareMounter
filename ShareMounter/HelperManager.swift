import Foundation
import ServiceManagement

@MainActor
final class HelperManager {
    static let shared = HelperManager()
    private init() {}

    func installHelper() {
        do {
            let service = SMAppService.loginItem(identifier: "ShareMounter.helper")
            try service.register()
            print("✅ Helper registered or already present")
        } catch {
            print("❌ Helper registration failed: \(error.localizedDescription)")
        }
    }

    func connection() -> NSXPCConnection {
        let c = NSXPCConnection(machServiceName: "ShareMounter.helper", options: [])
        c.remoteObjectInterface = NSXPCInterface(with: ShareMounterHelperProtocol.self)
        c.resume()
        return c
    }
}

