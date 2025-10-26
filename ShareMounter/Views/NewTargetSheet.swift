import SwiftUI
import Combine

struct NewTargetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var shareOrPath = ""
    @State private var username = ""
    @State private var password = ""          // 🔐
    @State private var portString = ""
    @State private var autoMount = true
    @State private var saveInKeychain = true  // 🔐

    var onSave: (MountTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Mount new target (SMB)", systemImage: "externaldrive.badge.plus")
                .font(.title2.bold())

            Divider()

            TextField("🌐 Host (e.g. 192.168.1.10, server or server.local)", text: $host)
                .textFieldStyle(.roundedBorder)

            TextField("📁 Share/Path (e.g. Media, Public or Backup)", text: $shareOrPath)
                .textFieldStyle(.roundedBorder)

            TextField("👤 Username", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("🔐 Password", text: $password)
                .textFieldStyle(.roundedBorder)

            TextField("🔌 Port (optional, e.g. 445)", text: $portString)
                .textFieldStyle(.roundedBorder)
                .onReceive(portString.publisher.collect()) { chars in
                    let filtered = String(chars.filter { "0123456789".contains($0) })
                    if filtered != portString { portString = filtered }
                }

            Toggle("Mount automatically", isOn: $autoMount)
            Toggle("Save password in keychain", isOn: $saveInKeychain)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add") { addTarget() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(.top, 10)
        }
        .padding(20)
        .frame(width: 440)
    }

    private var canSave: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !shareOrPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addTarget() {
        let newTarget = MountTarget(
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            shareOrPath: shareOrPath.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(portString),
            isEnabled: autoMount
        )

        if saveInKeychain, !password.isEmpty {
            _ = Keychain.set(password,
                             service: AppConstants.keychainService,
                             account: newTarget.keychainAccount)
        }

        onSave(newTarget)
        dismiss()
    }
}
