import Foundation
internal import UniformTypeIdentifiers

enum AppConstants {
    static let keychainService = "ShareMounter"

    static var appSupportDir: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "ShareMounter", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static var targetsFileURL: URL {
        appSupportDir.appendingPathComponent("targets.json", conformingTo: .json)
    }
}
