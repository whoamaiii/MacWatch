import SwiftUI

/// Main app entry point
@main
struct ClarityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
        MenuBarExtra("Clarity", systemImage: "chart.bar.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
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

/// Placeholder settings view
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            TrackingSettingsView()
                .tabItem {
                    Label("Tracking", systemImage: "eye")
                }

            DataSettingsView()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = true

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            Toggle("Show in Dock", isOn: $showDockIcon)
        }
        .padding()
    }
}

struct TrackingSettingsView: View {
    @AppStorage("trackWindows") private var trackWindows = true
    @AppStorage("trackInput") private var trackInput = true
    @AppStorage("trackSystem") private var trackSystem = true

    var body: some View {
        Form {
            Toggle("Track window focus", isOn: $trackWindows)
            Toggle("Track keyboard & mouse", isOn: $trackInput)
            Toggle("Track system events", isOn: $trackSystem)
        }
        .padding()
    }
}

struct DataSettingsView: View {
    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Database size", value: "12.4 MB")
                LabeledContent("Location", value: "~/Library/Application Support/Clarity")
            }

            Section("Export") {
                Button("Export to JSON...") {}
                Button("Export to CSV...") {}
            }

            Section("Danger Zone") {
                Button("Clear All Data...", role: .destructive) {}
            }
        }
        .padding()
    }
}
