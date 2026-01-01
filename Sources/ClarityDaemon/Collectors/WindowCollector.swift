import Foundation
import AppKit
import ClarityShared

/// Collects window and application focus events
final class WindowCollector {
    private let appRepo = AppRepository()
    private let statsRepo = StatsRepository()

    private var currentApp: NSRunningApplication?
    private var currentAppId: Int64?
    private var currentWindowTitle: String?
    private var focusStartTime: Date?

    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var activeSecondTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        // Listen for app activation
        let activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivate(notification)
        }
        observers.append(activateObserver)

        // Listen for app deactivation
        let deactivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppDeactivate(notification)
        }
        observers.append(deactivateObserver)

        // Listen for app launch
        let launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLaunch(notification)
        }
        observers.append(launchObserver)

        // Listen for app quit
        let quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppQuit(notification)
        }
        observers.append(quitObserver)

        // Poll for window title changes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollWindowTitle()
        }

        // Count active seconds
        activeSecondTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordActiveSecond()
        }

        // Record current app on start
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            recordAppSwitch(to: frontApp)
        }

        print("WindowCollector started")
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()

        pollTimer?.invalidate()
        pollTimer = nil

        activeSecondTimer?.invalidate()
        activeSecondTimer = nil

        // Record final session
        if let app = currentApp, let start = focusStartTime {
            recordSession(app: app, start: start, end: Date())
        }

        print("WindowCollector stopped")
    }

    // MARK: - Event Handlers

    private func handleAppActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        // Record previous session if any
        if let prevApp = currentApp, let start = focusStartTime {
            recordSession(app: prevApp, start: start, end: Date())
        }

        recordAppSwitch(to: app)
    }

    private func handleAppDeactivate(_ notification: Notification) {
        // Handled by activate of new app
    }

    private func handleAppLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              let name = app.localizedName else {
            return
        }

        // Ensure app is in database
        do {
            _ = try appRepo.findOrCreate(bundleId: bundleId, name: name)
        } catch {
            print("Error creating app record: \(error)")
        }
    }

    private func handleAppQuit(_ notification: Notification) {
        // Could log quit event if needed
    }

    // MARK: - Recording

    private func recordAppSwitch(to app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier,
              let name = app.localizedName else {
            return
        }

        currentApp = app
        focusStartTime = Date()

        do {
            let dbApp = try appRepo.findOrCreate(bundleId: bundleId, name: name)
            currentAppId = dbApp.id
            print("Switched to: \(name)")
        } catch {
            print("Error recording app switch: \(error)")
        }

        // Get initial window title
        pollWindowTitle()
    }

    private func recordSession(app: NSRunningApplication, start: Date, end: Date) {
        // Session data could be saved for detailed analysis
        let duration = end.timeIntervalSince(start)
        if duration > 5 { // Only log sessions > 5 seconds
            print("Session ended: \(app.localizedName ?? "Unknown") - \(Int(duration))s")
        }
    }

    private func recordActiveSecond() {
        guard let appId = currentAppId else { return }

        let now = Date()
        let minuteTimestamp = Int64(now.timeIntervalSince1970) / 60 * 60

        do {
            try statsRepo.recordMinuteStat(
                timestamp: minuteTimestamp,
                appId: appId,
                activeSeconds: 1
            )
        } catch {
            print("Error recording active second: \(error)")
        }
    }

    // MARK: - Window Title Polling

    private func pollWindowTitle() {
        guard let app = currentApp else { return }

        let title = getWindowTitle(for: app)

        if title != currentWindowTitle {
            currentWindowTitle = title
            if let title = title {
                print("Window title: \(title)")
            }
        }
    }

    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success, let window = focusedWindow else {
            return nil
        }

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &title
        )

        guard titleResult == .success, let titleString = title as? String else {
            return nil
        }

        return titleString
    }
}
