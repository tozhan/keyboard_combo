import AppKit
import SwiftUI

@main
struct KeyboardComboApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Keyboard Combo", id: "reports") {
            RootView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 660)
                .task {
                    await model.start()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    model.refreshPermissionAndCapture()
                }
        }
        .defaultSize(width: 1_080, height: 760)

        MenuBarExtra("Keyboard Combo", systemImage: "keyboard") {
            MenuBarView()
                .environment(model)
                .task {
                    await model.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .frame(width: 500)
        }
    }
}

private struct RootView: View {
    var body: some View {
        ReportsView()
    }
}
