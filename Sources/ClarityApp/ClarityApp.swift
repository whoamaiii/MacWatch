import SwiftUI

/// Main app entry point
@main
struct ClarityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar widget
        MenuBarExtra("Clarity", systemImage: "chart.bar.fill", isInserted: $showInMenuBar) {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        // Settings window (CMD+,)
        Settings {
            SettingsWindowView()
        }
    }
}

/// App delegate for handling app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running for menu bar
        false
    }
}

/// macOS Settings window (CMD+,)
struct SettingsWindowView: View {
    var body: some View {
        SettingsView()
            .frame(minWidth: 700, minHeight: 600)
    }
}
