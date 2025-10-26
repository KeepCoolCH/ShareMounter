import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var helperInstalled = false
    @State private var showNewTargetSheet = false
    @State private var editTarget: MountTarget? = nil
    @State private var deleteCandidate: MountTarget? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.title2.bold())
                .padding(.bottom, 8)

            Divider()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task {
                            HelperManager.shared.installHelper()
                            await MainActor.run { helperInstalled = true }
                        }
                    } label: {
                        Label("Install Helper Tool", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.borderedProminent)

                    if helperInstalled {
                        Label("Helper installed or already active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                .padding(6)
            } label: {
                Label("Helper Tool", systemImage: "hammer.fill")
            }

            Divider().padding(.vertical, 8)

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if vm.targets.isEmpty {
                        Text("No mount targets available. Add one in the menu.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(vm.targets) { t in
                                HStack(alignment: .center, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(t.host)
                                            Text("~/Volumes/\(t.resolvedMountName)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                    Spacer(minLength: 8)

                                    Button {
                                        editTarget = t
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Edit target")

                                    Button(role: .destructive) {
                                        deleteCandidate = t
                                        showDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete target")
                                }
                                .padding(8)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.top, 4)
                    }

                    HStack {
                        Button("➕ New target (SMB)") { showNewTargetSheet = true }
                    }
                    .padding(.top, 6)
                }
                .padding(6)
            } label: {
                Label("Mount target (SMB)", systemImage: "externaldrive.fill")
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 400)
        .onAppear { helperInstalled = true }
        .sheet(item: $editTarget) { target in
            EditTargetSheet(original: target) { updated, passwordAction in
                guard let idx = vm.targets.firstIndex(of: target) else { return }
                let oldAccount = vm.targets[idx].keychainAccount
                let newAccount = updated.keychainAccount

                vm.targets[idx] = updated

                switch passwordAction {
                case .keep:
                    if oldAccount != newAccount {
                        let (pw, status) = Keychain.get(service: AppConstants.keychainService, account: oldAccount)
                        if status == errSecSuccess, let pw {
                            _ = Keychain.set(pw, service: AppConstants.keychainService, account: newAccount)
                            _ = Keychain.delete(service: AppConstants.keychainService, account: oldAccount)
                        }
                    }
                case .set(let newPW):
                    if oldAccount != newAccount {
                        _ = Keychain.delete(service: AppConstants.keychainService, account: oldAccount)
                    }
                    _ = Keychain.set(newPW, service: AppConstants.keychainService, account: newAccount)
                case .delete:
                    _ = Keychain.delete(service: AppConstants.keychainService, account: oldAccount)
                    if oldAccount != newAccount {
                        _ = Keychain.delete(service: AppConstants.keychainService, account: newAccount)
                    }
                }

                vm.appendLog("✏️ Target updated: \(updated.host)")
            }
        }

        .alert("Delete target?", isPresented: $showDeleteAlert, presenting: deleteCandidate) { t in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                _ = Keychain.delete(service: AppConstants.keychainService, account: t.keychainAccount)
                vm.targets.removeAll { $0.id == t.id }
                vm.appendLog("🗑️ Target deleted: \(t.host)")
            }
        } message: { t in
            Text("\(t.host) – ~/Volumes/\(t.resolvedMountName)")
        }

        .sheet(isPresented: $showNewTargetSheet) {
            NewTargetSheet { newTarget in
                vm.targets.append(newTarget)
                vm.appendLog("📁 New target added: \(newTarget.host)")

                DispatchQueue.global(qos: .userInitiated).async {
                    let (pw, status) = Keychain.get(service: AppConstants.keychainService,
                                                    account: newTarget.keychainAccount)
                    guard let pw, !pw.isEmpty else {
                        DispatchQueue.main.async {
                            vm.appendLog("🔒 No password in keychain for \(newTarget.keychainAccount) (status: \(status))")
                        }
                        return
                    }

                    do {
                        try Mounter.shared.mount(newTarget, password: pw)
                        DispatchQueue.main.async {
                            vm.appendLog("✅ Mounted automatically: \(newTarget.host)\(newTarget.port.map{":\($0)"} ?? "")/\(newTarget.shareOrPath)")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            vm.appendLog("❌ Auto-Mount-Error \(newTarget.host): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func binding<T>(for t: MountTarget, keyPath: WritableKeyPath<MountTarget, T>) -> Binding<T> {
        guard let idx = vm.targets.firstIndex(of: t) else {
            return .constant(t[keyPath: keyPath])
        }
        return Binding(
            get: { vm.targets[idx][keyPath: keyPath] },
            set: { vm.targets[idx][keyPath: keyPath] = $0 }
        )
    }
}
