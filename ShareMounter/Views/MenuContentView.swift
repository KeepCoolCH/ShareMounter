import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var refreshingMounted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ShareMounter (SMB)", systemImage: "externaldrive.connected.to.line.below")
                    .font(.title3.bold())
                Spacer()
                // 🔄 Refresh
                Button {
                    refreshingMounted = true
                    vm.refreshStatusNow(clearLog: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        refreshingMounted = false
                    }
                } label: {
                    if refreshingMounted { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .help("Refresh mount status")

                // ⚙️ Settings
                Button {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

                // ❌ Quit
                Button(role: .destructive) {
                    quitAndUnmount()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Unmount all and quit app")
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    mountAll()
                } label: {
                    Label("Mount all", systemImage: "link.badge.plus")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    unmountAll()
                } label: {
                    Label("Unmount all", systemImage: "eject.fill")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            GroupBox {
                if vm.targets.isEmpty {
                    Text("No mount targets available. Add one in the settings.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(vm.targets) { t in
                            TargetRow(
                                target: t,
                                onMount: { mountOne(t) },
                                onUnmount: { unmountOne(t) },
                                onReveal: { revealInFinder(t) }
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            } label: {
                Label("Mount targets (SMB)", systemImage: "externaldrive.fill")
            }

            GroupBox {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(vm.logLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 80, maxHeight: 140)
            } label: {
                Label("Log", systemImage: "doc.plaintext")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 560)
        .onAppear { vm.refreshStatusNow() }
    }

    // MARK: - Mounting
    private func mountAll() {
        for t in vm.targets where t.isEnabled {
            mountOne(t)
        }
    }

    private func unmountAll() {
        for t in vm.targets {
            unmountOne(t)
        }
    }

    private func mountOne(_ t: MountTarget) {
        let (pw, status) = Keychain.get(service: AppConstants.keychainService, account: t.keychainAccount)
        guard let pw, !pw.isEmpty else {
            vm.appendLog("🔒 No password in keychain for \(t.keychainAccount) (status: \(status))")
            return
        }
        do {
            try Mounter.shared.mount(t, password: pw)
            vm.appendLog("✅ Mounted: \(t.host)\(t.port.map{":\($0)"} ?? "")/\(t.shareOrPath)")
            vm.unregisterManualUnmount(for: t)
            vm.refreshStatusNow()
        } catch {
            vm.appendLog("❌ Mount-Error \(t.host): \(error.localizedDescription)")
        }
    }

    private func unmountOne(_ t: MountTarget) {
        do {
            try Mounter.shared.unmount(name: t.resolvedMountName, force: true)
            vm.appendLog("⏏️ Unmounted: \(t.host)\(t.port.map{":\($0)"} ?? "")/\(t.shareOrPath)")
            vm.registerManualUnmount(for: t)
            vm.refreshStatusNow()
        } catch {
            vm.appendLog("❌ Unmount error \(t.resolvedMountName): \(error.localizedDescription)")
        }
    }

    // MARK: - Quit
    private func quitAndUnmount() {
        for t in vm.targets {
            do {
                try Mounter.shared.unmount(name: t.resolvedMountName, force: true)
                vm.appendLog("⏏️ Unmounted: \(t.resolvedMountName)")
            } catch {
                vm.appendLog("⚠️ Unmount error \(t.resolvedMountName): \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Finder
    private func revealInFinder(_ t: MountTarget) {
        let path = Mounter.sharedPath(for: t)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else {
            vm.appendLog("ℹ️ Not yet mounted: \(path)")
        }
    }
}

// MARK: - TargetRow (Anzeige der einzelnen Mounts)
private struct TargetRow: View {
    let target: MountTarget
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(target.isOnline ? .green : .gray.opacity(0.5))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.host)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("/\(target.shareOrPath.trimmingCharacters(in: .init(charactersIn: "/")))")
                    if let p = target.port {
                        Text("• Port \(p)")
                    }
                    Text("• \(target.username)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button { onReveal() } label: { Image(systemName: "folder") }
                .help("Show in Finder")

            if target.isOnline {
                Button(role: .destructive) { onUnmount() } label: {
                    Label("Unmount", systemImage: "eject.fill").labelStyle(.iconOnly)
                }
                .help("Unmount")
            } else {
                Button { onMount() } label: {
                    Label("Mount", systemImage: "link").labelStyle(.iconOnly)
                }
                .help("Mount")
                .disabled(!target.isEnabled)
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
