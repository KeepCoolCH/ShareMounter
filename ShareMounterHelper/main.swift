import Foundation

final class Helper: NSObject, NSXPCListenerDelegate, ShareMounterHelperProtocol {
    private let listener = NSXPCListener(machServiceName: "ShareMounter.helper")

    override init() {
        super.init()
        listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        c.exportedInterface = NSXPCInterface(with: ShareMounterHelperProtocol.self)
        c.exportedObject = self
        c.resume()
        return true
    }

    func mountSMB(url: String, mountPoint: String, reply: @escaping (Bool, String) -> Void) {
        do {
            try ensureDir(path: mountPoint)
            let out = try run("/sbin/mount_smbfs", [url, mountPoint])
            reply(true, out)
        } catch {
            reply(false, "\(error)")
        }
    }

    func unmount(path: String, force: Bool, reply: @escaping (Bool, String) -> Void) {
        do {
            try run("/sbin/umount", [path])
            reply(true, "OK")
        } catch {
            if force {
                _ = try? run("/sbin/umount", ["-f", path])
                _ = try? run("/usr/sbin/diskutil", ["unmountForce", path])
                reply(true, "Forced")
            } else {
                reply(false, "\(error)")
            }
        }
    }

    private func ensureDir(path: String) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    private func run(_ cmd: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        try p.run(); p.waitUntilExit()
        let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if p.terminationStatus != 0 {
            throw NSError(domain: "ShareMounter.helper", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: e.isEmpty ? s : e])
        }
        return s
    }
}

Helper().run()
