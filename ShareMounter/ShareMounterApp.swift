import SwiftUI

@main
struct ShareMounterApp: App {
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        MenuBarExtra("ShareMounter", systemImage: "externaldrive.connected.to.line.below") {
            MenuContentView()
                .environmentObject(vm)
                .frame(minWidth: 560, minHeight: 420)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(vm)
        }
        .defaultSize(width: 520, height: 420)
    }
}
