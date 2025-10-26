import Foundation

enum MounterError: Error, LocalizedError {
    case missingPassword
    case commandFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .missingPassword:
            return "No password stored in the keychain."
        case .commandFailed(let msg):
            return "Mount/Unmount error: \(msg)"
        case .timeout(let what):
            return "Operation timed out: \(what)"
        }
    }
}

final class Mounter {
    static let shared = Mounter()
    private init() {}

    private let fm = FileManager.default

    private var userVolumesRoot: String {
        (fm.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("Volumes")
    }

    private func mountPath(for name: String) -> String {
        (userVolumesRoot as NSString).appendingPathComponent(name)
    }

    static func sharedPath(for t: MountTarget) -> String {
        Mounter.shared.mountPath(for: t.resolvedMountName)
    }

    func sharedPath(for t: MountTarget) -> String {
        mountPath(for: t.resolvedMountName)
    }

    // ---------- Status ----------
    private func isMountpointActive(_ path: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/sbin/mount")
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let out = String(data: data, encoding: .utf8) else { return false }
            return out.split(separator: "\n").contains { $0.contains(" on \(path) (smbfs") }
        } catch { return false }
    }

    func isMounted(_ name: String) -> Bool {
        isMountpointActive(mountPath(for: name))
    }

    // ---------- Unmount ----------
    func unmount(name: String, force: Bool = true) throws {
        let path = mountPath(for: name)

        if isMountpointActive(path) {
            if runUmount(args: [path]) != 0 {
                if !(force && runUmount(args: ["-f", path]) == 0) {
                    if runDiskutil(args: ["unmount", "force", path]) != 0 {
                        throw MounterError.commandFailed("Unmount failed for \(path)")
                    }
                }
            }
        }

        try cleanupStaleMountpoint(path)
    }

    private func runUmount(args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/sbin/umount")
        p.arguments = args
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }

    private func runDiskutil(args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        p.arguments = args
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }

    private func benignEntries(_ list: [String]) -> Bool {
        let allowed: Set<String> = [".DS_Store", ".metadata_never_index", ".fseventsd", ".hidden"]
        return Set(list).isSubset(of: allowed)
    }

    private func cleanupStaleMountpoint(_ path: String) throws {
        guard fm.fileExists(atPath: path) else { return }
        if isMountpointActive(path) { return }
        let contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
        if contents.isEmpty || benignEntries(contents) {
            try? fm.removeItem(atPath: (path as NSString).appendingPathComponent(".DS_Store"))
            try fm.removeItem(atPath: path)
            return
        }
        let ts = Int(Date().timeIntervalSince1970)
        let backup = path + ".stale-\(ts)"
        try fm.moveItem(atPath: path, toPath: backup)
    }

    private func prepareFreshMountpoint(_ path: String) throws {
        try? fm.createDirectory(atPath: userVolumesRoot, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])

        if isMountpointActive(path) { return }
        if fm.fileExists(atPath: path) {
            try cleanupStaleMountpoint(path)
        }
        if !fm.fileExists(atPath: path) {
            try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    // ---------- Mount ----------
    func mount(_ t: MountTarget, password: String) throws {
        let name = t.resolvedMountName
        let mountPoint = mountPath(for: name)

        try prepareFreshMountpoint(mountPoint)
        if isMountpointActive(mountPoint) { return }

        let attempts = hostAttempts(for: t)

        var lastErr: Error?
        for (host, candidatePort) in attempts {
            let port = candidatePort ?? t.port
            let url = smbURL(host: host,
                             port: port,
                             share: t.shareOrPath,
                             user: t.username,
                             password: password)
            do {
                try mountURL(url, at: mountPoint)
                if isMountpointActive(mountPoint) { return }
            } catch {
                lastErr = error
            }
        }

        if !isMountpointActive(mountPoint) {
            try cleanupStaleMountpoint(mountPoint)
        }
        throw lastErr ?? MounterError.commandFailed("No reachable host variant")
    }

    private func smbURL(host: String, port: Int?, share: String, user: String, password: String) -> URL {
        let encUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
        let encPw = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
        var hostPart = host
        if let p = port { hostPart += ":\(p)" }
        var sharePart = share.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sharePart.hasPrefix("/") { sharePart = "/\(sharePart)" }
        let s = "smb://\(encUser):\(encPw)@\(hostPart)\(sharePart)"
        return URL(string: s)!
    }

    private func mountURL(_ url: URL, at mountPoint: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        task.arguments = [url.absoluteString, mountPoint]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let msg = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw MounterError.commandFailed(msg)
        }
    }

    // ---------- Host resolution (direct, .local, Bonjour) ----------
    private func hostAttempts(for t: MountTarget) -> [(host: String, port: Int?)] {
        var out: [(host: String, port: Int?)] = []
        let h = t.host.trimmingCharacters(in: .whitespacesAndNewlines)

        if h.lowercased().hasSuffix(".local") {
            out.append((host: h, port: nil))
            let base = String(h.dropLast(6))
            if !base.isEmpty { out.append((host: base, port: nil)) }
        } else {
            out.append((host: h, port: nil))
            if !h.contains(".") { out.append((host: "\(h).local", port: nil)) }
        }

        if let bonjour = BonjourSMBResolver.resolve(name: bareName(from: h), timeout: 2.0) {
            out.append((host: bonjour.host, port: bonjour.port))
        }

        var seen = Set<String>()
        out = out.filter { attempt in
            let key = attempt.host.lowercased() + ":\(attempt.port ?? -1)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        return out
    }

    private func bareName(from host: String) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dot = trimmed.firstIndex(of: ".") {
            return String(trimmed[..<dot])
        }
        return trimmed
    }
}

final class BonjourSMBResolver: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var found: NetService?
    private var result: (host: String, port: Int)?
    private let sem = DispatchSemaphore(value: 0)
    private var targetName: String = ""

    static func resolve(name: String, timeout: TimeInterval) -> (host: String, port: Int)? {
        let r = BonjourSMBResolver()
        r.targetName = name
        return r.search(timeout: timeout)
    }

    private func search(timeout: TimeInterval) -> (host: String, port: Int)? {
        browser.delegate = self
        browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
        _ = sem.wait(timeout: .now() + timeout)
        browser.stop()
        return result
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if service.name.caseInsensitiveCompare(targetName) == .orderedSame {
            found = service
            service.delegate = self
            service.resolve(withTimeout: 1.5)
        }
        if !moreComing, found == nil {
            sem.signal()
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let host = sender.hostName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? ""
        if !host.isEmpty {
            result = (host: host, port: sender.port > 0 ? sender.port : 445)
        }
        sem.signal()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        sem.signal()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        sem.signal()
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {}
}
