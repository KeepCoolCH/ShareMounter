import Foundation
import Combine

final class AppViewModel: ObservableObject {
    @Published var targets: [MountTarget] = [] {
        didSet { saveTargets() }
    }
    @Published var logLines: [String] = []

    private let reconnectInterval: TimeInterval = 30
    private let minRetryGapPerTarget: TimeInterval = 10
    private var reconnectTimer: DispatchSourceTimer?
    private var lastReconnectAttempt: [UUID: Date] = [:]
    private var manuallyUnmounted: Set<UUID> = []

    init() {
        loadTargets()
        updateMountStatuses()
        autoMountEnabledTargetsOnLaunch()
        startAutoReconnect()
    }

    func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.logLines.append(s)
            print(s)
        }
    }

    private func saveTargets() {
        do {
            let data = try JSONEncoder().encode(targets)
            try data.write(to: AppConstants.targetsFileURL, options: [.atomic])
        } catch {
            appendLog("❌ Could not save targets: \(error.localizedDescription)")
        }
    }

    private func loadTargets() {
        do {
            let url = AppConstants.targetsFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([MountTarget].self, from: data)
            self.targets = decoded
        } catch {
            appendLog("⚠️ Could not load targets: \(error.localizedDescription)")
        }
    }

    func autoMountEnabledTargetsOnLaunch() {
        DispatchQueue.global(qos: .userInitiated).async {
            for t in self.targets where t.isEnabled {
                let (pw, status) = Keychain.get(service: AppConstants.keychainService, account: t.keychainAccount)
                guard let pw, !pw.isEmpty else {
                    DispatchQueue.main.async {
                        self.appendLog("🔒 No password in keychain for \(t.keychainAccount) (status: \(status))")
                    }
                    continue
                }
                do {
                    try Mounter.shared.mount(t, password: pw)
                    DispatchQueue.main.async {
                        self.appendLog("✅ Automatically mounted: \(t.host)\(t.port.map{":\($0)"} ?? "")/\(t.shareOrPath)")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.appendLog("❌ Auto-mount error \(t.host): \(error.localizedDescription)")
                    }
                }
            }
            self.updateMountStatuses()
        }
    }

    private func startAutoReconnect() {
        reconnectTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: reconnectInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.updateMountStatuses()
            self.checkAndReconnectAll()
        }
        timer.resume()
        reconnectTimer = timer
    }

    private func checkAndReconnectAll() {
        for t in targets where t.isEnabled {
            if manuallyUnmounted.contains(t.id) { continue }
            if Mounter.shared.isMounted(t.resolvedMountName) { continue }
            if let last = lastReconnectAttempt[t.id], Date().timeIntervalSince(last) < minRetryGapPerTarget {
                continue
            }
            lastReconnectAttempt[t.id] = Date()
            let (pw, _) = Keychain.get(service: AppConstants.keychainService, account: t.keychainAccount)
            guard let pw, !pw.isEmpty else {
                DispatchQueue.main.async {
                    self.appendLog("🔒 Reconnect skipped: no password for \(t.keychainAccount)")
                }
                continue
            }
            do {
                try Mounter.shared.mount(t, password: pw)
                DispatchQueue.main.async {
                    self.appendLog("🔗 Reconnected: \(t.host)/\(t.shareOrPath)")
                }
            } catch {
                DispatchQueue.main.async {
                }
            }
        }
    }

    func refreshStatusNow(clearLog: Bool = false) {
        if clearLog {
            DispatchQueue.main.async { [weak self] in
                self?.logLines.removeAll()
            }
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.updateMountStatuses()
        }
    }

    func registerManualUnmount(for target: MountTarget) {
        manuallyUnmounted.insert(target.id)
    }

    func unregisterManualUnmount(for target: MountTarget) {
        if manuallyUnmounted.remove(target.id) != nil {
        }
    }

    private func updateMountStatuses() {
        var updated = false
        var newTargets = targets
        for i in newTargets.indices {
            let t = newTargets[i]
            let mounted = Mounter.shared.isMounted(t.resolvedMountName)
            if t.isOnline != mounted {
                newTargets[i].isOnline = mounted
                updated = true
            }
        }
        if updated {
            DispatchQueue.main.async {
                self.targets = newTargets
                self.saveTargets()
            }
        }
    }
}
