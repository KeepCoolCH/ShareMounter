import Foundation

final class Storage {
static let shared = Storage()
private init() {}

private var dir: URL {
let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let folder = base.appendingPathComponent("ShareMounter", isDirectory: true)
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
return folder
}

private var targetsURL: URL { dir.appendingPathComponent("targets.json") }

func loadTargets() -> [MountTarget] {
guard let data = try? Data(contentsOf: targetsURL) else { return [] }
return (try? JSONDecoder().decode([MountTarget].self, from: data)) ?? []
}

func saveTargets(_ arr: [MountTarget]) {
let data = try? JSONEncoder().encode(arr)
try? data?.write(to: targetsURL)
}
}
