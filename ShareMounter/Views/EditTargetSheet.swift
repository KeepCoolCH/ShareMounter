import SwiftUI
import Combine

enum PasswordEditAction: Equatable {
    case keep
    case set(String)
    case delete
}

struct EditTargetSheet: View {
    let original: MountTarget
    var onSave: (_ updated: MountTarget, _ passwordAction: PasswordEditAction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var host: String
    @State private var shareOrPath: String
    @State private var username: String
    @State private var portString: String

    @State private var passwordMode: PasswordMode = .keep
    @State private var newPassword: String = ""

    enum PasswordMode: String, CaseIterable, Identifiable {
        case keep = "Keep password"
        case set  = "New password"
        case delete = "Delete password"
        var id: String { rawValue }
    }

    init(original: MountTarget,
         onSave: @escaping (_ updated: MountTarget, _ passwordAction: PasswordEditAction) -> Void) {
        self.original = original
        self.onSave = onSave
        _host = State(initialValue: original.host)
        _shareOrPath = State(initialValue: original.shareOrPath)
        _username = State(initialValue: original.username)
        _portString = State(initialValue: original.port.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Edit target", systemImage: "pencil")
                .font(.title2.bold())

            Divider()

            TextField("🌐 Host", text: $host)
                .textFieldStyle(.roundedBorder)

            TextField("📁 Share/Path", text: $shareOrPath)
                .textFieldStyle(.roundedBorder)

            TextField("👤 Username", text: $username)
                .textFieldStyle(.roundedBorder)

            TextField("🔌 Port (optional)", text: $portString)
                .textFieldStyle(.roundedBorder)
                .onReceive(portString.publisher.collect()) { chars in
                    let filtered = String(chars.filter { "0123456789".contains($0) })
                    if filtered != portString { portString = filtered }
                }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Password", selection: $passwordMode) {
                        Text("Keep password").tag(PasswordMode.keep)
                        Text("New password").tag(PasswordMode.set)
                        Text("Delete password").tag(PasswordMode.delete)
                    }
                    .pickerStyle(.segmented)

                    if passwordMode == .set {
                        SecureField("New password", text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            } label: {
                Label("Password", systemImage: "key.fill")
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(width: 420)
    }

    private var canSave: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !shareOrPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (passwordMode != .set || !newPassword.isEmpty)
    }

    private func save() {
        let updated = MountTarget(
            id: original.id,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            shareOrPath: shareOrPath.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(portString),
            isEnabled: original.isEnabled
        )

        let action: PasswordEditAction
        switch passwordMode {
        case .keep:
            action = .keep
        case .set:
            action = .set(newPassword)
        case .delete:
            action = .delete
        }

        onSave(updated, action)
        dismiss()
    }
}
