import Foundation

struct MountTarget: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var name: String = ""
    var host: String
    var shareOrPath: String
    var username: String
    var port: Int?
    var isEnabled: Bool = true
    var isOnline: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, host, shareOrPath, username, port, isEnabled, isOnline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name        = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.host        = try c.decode(String.self, forKey: .host)
        self.shareOrPath = try c.decode(String.self, forKey: .shareOrPath)
        self.username    = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.port        = try c.decodeIfPresent(Int.self, forKey: .port)
        self.isEnabled   = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.isOnline    = false
    }

    init(id: UUID = UUID(),
         name: String = "",
         host: String,
         shareOrPath: String,
         username: String,
         port: Int? = nil,
         isEnabled: Bool = true,
         isOnline: Bool = false)
    {
        self.id = id
        self.name = name
        self.host = host
        self.shareOrPath = shareOrPath
        self.username = username
        self.port = port
        self.isEnabled = isEnabled
        self.isOnline = isOnline
    }

    var keychainAccount: String {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var cleanShare = shareOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanShare.hasPrefix("/") { cleanShare = "/" + cleanShare }
        cleanShare = cleanShare.replacingOccurrences(of: "//+", with: "/", options: .regularExpression)
        return "smb:\(cleanHost)\(cleanShare)"
    }

    var resolvedMountName: String {
        let base: String = {
            let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !display.isEmpty { return display }
            let lastComponent = shareOrPath
                .split(separator: "/")
                .last
                .map(String.init) ?? shareOrPath
            return "smb_\(host)_\(lastComponent)"
        }()
        return MountTarget.sanitizeFilesystemName(base)
    }

    // MARK: - Helpers

    private static func sanitizeFilesystemName(_ input: String) -> String {
        var s = input.replacingOccurrences(of: "[^A-Za-z0-9._-]+",
                                           with: "_",
                                           options: .regularExpression)
        s = s.replacingOccurrences(of: "_{2,}",
                                   with: "_",
                                   options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "._- "))
        if s.count > 64 { s = String(s.prefix(64)) }
        return s.isEmpty ? "smb_mount" : s
    }
}
