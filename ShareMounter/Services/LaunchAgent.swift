import Foundation

enum LaunchAgent {
static let identifier = "ShareMounter"

static func makePlist() -> String {
return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Label</key>
<string>\(identifier)</string>
<key>ProgramArguments</key>
<array>
<string>\(Bundle.main.executablePath ?? "")</string>
<string>--automount</string>
</array>
<key>RunAtLoad</key>
<true/>
<key>KeepAlive</key>
<false/>
<key>StandardOutPath</key>
<string>~/Library/Logs/ShareMounter.out.log</string>
<key>StandardErrorPath</key>
<string>~/Library/Logs/ShareMounter.err.log</string>
</dict>
</plist>
"""
}

static func install(plist: String, enable: Bool) throws {
let agents = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
try FileManager.default.createDirectory(atPath: agents, withIntermediateDirectories: true)
let path = (agents as NSString).appendingPathComponent("\(identifier).plist")
try plist.data(using: .utf8)!.write(to: URL(fileURLWithPath: path))

let bin = "/bin/launchctl"
if enable {
_ = try run(bin, ["unload", path])
_ = try run(bin, ["load", path])
} else {
_ = try run(bin, ["unload", path])
}
}

@discardableResult
private static func run(_ cmd: String, _ args: [String]) throws -> String {
let p = Process(); p.executableURL = URL(fileURLWithPath: cmd); p.arguments = args
let out = Pipe(); let err = Pipe(); p.standardOutput = out; p.standardError = err
try p.run(); p.waitUntilExit()
let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
if p.terminationStatus != 0 { throw NSError(domain: "LaunchAgent", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: s]) }
return s
}
}
