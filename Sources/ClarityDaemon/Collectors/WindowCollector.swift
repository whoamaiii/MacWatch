import Foundation
import AppKit
import ClarityShared

/// Collects window and application focus events
final class WindowCollector {
    private let appRepo = AppRepository()
    private let statsRepo = StatsRepository()
    private let settings = TrackingSettings.shared

    private var currentApp: NSRunningApplication?
    private var currentAppId: Int64?
    private var currentWindowTitle: String?
    private var currentBrowserTabTitle: String?
    private var focusStartTime: Date?

    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var activeSecondTimer: Timer?

    // Context switch tracking
    private var contextSwitchCount: Int = 0
    private var lastContextSwitchDate: Date = Date()
    private var lastAppBundleId: String?

    // Meeting detection
    private var isInMeeting: Bool = false
    private var meetingStartTime: Date?
    private var meetingAppBundleId: String?
    private var meetingEndGraceTimer: Timer?
    private static let meetingGracePeriod: TimeInterval = 120 // 2 minutes grace period

    // Meeting app bundle IDs
    private static let meetingApps: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan",  // Google Meet in Chrome
        "com.webex.meetingmanager",
        "com.cisco.webexmeetingsapp",
        "com.facetime",
        "com.apple.FaceTime",
        "com.slack.Slack",
        "com.discord.Discord"
    ]

    // Browser bundle IDs for tab title extraction
    private static let browserApps: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "company.thebrowser.Browser",  // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]

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

        meetingEndGraceTimer?.invalidate()
        meetingEndGraceTimer = nil

        // End any active meeting
        if isInMeeting {
            endMeeting()
        }

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
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        // If the meeting app quit, end the meeting immediately
        if isInMeeting && meetingAppBundleId == bundleId {
            meetingEndGraceTimer?.invalidate()
            meetingEndGraceTimer = nil
            endMeeting()
        }
    }

    // MARK: - Recording

    private func recordAppSwitch(to app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier,
              let name = app.localizedName else {
            return
        }

        // Track context switches (only if switching to a different app)
        if let lastBundle = lastAppBundleId, lastBundle != bundleId {
            trackContextSwitch()
        }
        lastAppBundleId = bundleId

        // Check for meeting apps
        checkMeetingStatus(bundleId: bundleId)

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

    private func trackContextSwitch() {
        // Reset counter if it's a new day
        let calendar = Calendar.current
        if !calendar.isDate(lastContextSwitchDate, inSameDayAs: Date()) {
            contextSwitchCount = 0
            lastContextSwitchDate = Date()
        }

        contextSwitchCount += 1

        // Store context switch in raw events
        do {
            try DatabaseManager.shared.write { db in
                let data: [String: Int] = ["count": contextSwitchCount]
                let jsonData = try JSONEncoder().encode(data)
                let jsonString = jsonData.base64EncodedString()
                try db.execute(
                    sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                    arguments: [Date(), "contextSwitch", jsonString]
                )
            }
        } catch {
            print("Error recording context switch: \(error)")
        }
    }

    private func isMeetingApp(_ bundleId: String) -> Bool {
        Self.meetingApps.contains(bundleId) ||
        bundleId.lowercased().contains("zoom") ||
        bundleId.lowercased().contains("teams") ||
        bundleId.lowercased().contains("meet") ||
        bundleId.lowercased().contains("webex")
    }

    private func checkMeetingStatus(bundleId: String) {
        let isMeeting = isMeetingApp(bundleId)

        if isMeeting && !isInMeeting {
            // Started a meeting
            isInMeeting = true
            meetingStartTime = Date()
            meetingAppBundleId = bundleId
            meetingEndGraceTimer?.invalidate()
            meetingEndGraceTimer = nil
            print("Meeting started with: \(bundleId)")

            // Record meeting start event
            do {
                try DatabaseManager.shared.write { db in
                    let data: [String: String] = ["app": bundleId, "action": "start"]
                    let jsonData = try JSONEncoder().encode(data)
                    let jsonString = jsonData.base64EncodedString()
                    try db.execute(
                        sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                        arguments: [Date(), "meeting", jsonString]
                    )
                }
            } catch {
                print("Error recording meeting start: \(error)")
            }
        } else if isMeeting && isInMeeting {
            // User returned to meeting app - cancel grace timer
            meetingEndGraceTimer?.invalidate()
            meetingEndGraceTimer = nil
        } else if !isMeeting && isInMeeting && meetingEndGraceTimer == nil {
            // Switched away from meeting app - start grace period
            // Explicitly schedule on main run loop for reliability
            let timer = Timer(timeInterval: Self.meetingGracePeriod, repeats: false) { [weak self] _ in
                self?.endMeeting()
            }
            RunLoop.main.add(timer, forMode: .common)
            meetingEndGraceTimer = timer
        }
    }

    private func endMeeting() {
        guard isInMeeting, let startTime = meetingStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        print("Meeting ended, duration: \(Int(duration))s")

        // Record meeting end event
        do {
            try DatabaseManager.shared.write { db in
                let data: [String: Any] = ["action": "end", "duration": Int(duration)]
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let jsonString = jsonData.base64EncodedString()
                try db.execute(
                    sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                    arguments: [Date(), "meeting", jsonString]
                )
            }
        } catch {
            print("Error recording meeting end: \(error)")
        }

        isInMeeting = false
        meetingStartTime = nil
        meetingAppBundleId = nil
        meetingEndGraceTimer?.invalidate()
        meetingEndGraceTimer = nil
    }

    private func recordSession(app: NSRunningApplication, start: Date, end: Date) {
        // Session data could be saved for detailed analysis
        let duration = end.timeIntervalSince(start)
        if duration > 5 { // Only log sessions > 5 seconds
            print("Session ended: \(app.localizedName ?? "Unknown") - \(Int(duration))s")
        }
    }

    private func recordActiveSecond() {
        guard settings.windowTrackingEnabled else { return }
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
        guard let app = currentApp,
              let bundleId = app.bundleIdentifier else { return }

        let title = getWindowTitle(for: app)

        if title != currentWindowTitle {
            currentWindowTitle = title
            if let title = title {
                print("Window title: \(title)")
            }
        }

        // Extract browser tab title if this is a browser
        if Self.browserApps.contains(bundleId) {
            let tabTitle = getBrowserTabTitle(bundleId: bundleId)
            if tabTitle != currentBrowserTabTitle {
                currentBrowserTabTitle = tabTitle
                if let tabTitle = tabTitle {
                    print("Browser tab: \(tabTitle)")
                    saveBrowserTabEvent(bundleId: bundleId, tabTitle: tabTitle)
                }
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

        guard result == .success,
              let window = focusedWindow,
              CFGetTypeID(window as CFTypeRef) == AXUIElementGetTypeID() else {
            return nil
        }

        // Safe cast after type ID verification - use unsafeBitCast for AXUIElement
        let axWindow = unsafeBitCast(window, to: AXUIElement.self)

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            axWindow,
            kAXTitleAttribute as CFString,
            &title
        )

        guard titleResult == .success, let titleString = title as? String else {
            return nil
        }

        return titleString
    }

    // MARK: - Browser Tab Title Extraction

    private func getBrowserTabTitle(bundleId: String) -> String? {
        switch bundleId {
        case "com.apple.Safari":
            return getSafariTabTitle()
        case "com.google.Chrome", "com.google.Chrome.canary", "com.brave.Browser",
             "com.microsoft.edgemac", "com.operasoftware.Opera", "com.vivaldi.Vivaldi":
            return getChromiumTabTitle(appName: getChromiumAppName(bundleId: bundleId))
        case "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition":
            return getFirefoxTabTitle()
        case "company.thebrowser.Browser":
            return getArcTabTitle()
        default:
            return nil
        }
    }

    private func getChromiumAppName(bundleId: String) -> String {
        switch bundleId {
        case "com.google.Chrome": return "Google Chrome"
        case "com.google.Chrome.canary": return "Google Chrome Canary"
        case "com.brave.Browser": return "Brave Browser"
        case "com.microsoft.edgemac": return "Microsoft Edge"
        case "com.operasoftware.Opera": return "Opera"
        case "com.vivaldi.Vivaldi": return "Vivaldi"
        default: return "Google Chrome"
        }
    }

    private func getSafariTabTitle() -> String? {
        let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return name of current tab of front window
                end if
            end tell
        """
        return runAppleScript(script)
    }

    private func getChromiumTabTitle(appName: String) -> String? {
        // Validate app name contains only safe characters (alphanumeric, spaces, basic punctuation)
        // This prevents AppleScript injection from malicious app names
        let safeCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-_"))
        guard appName.unicodeScalars.allSatisfy({ safeCharacterSet.contains($0) }) else {
            print("Warning: Rejecting unsafe app name for AppleScript: \(appName)")
            return nil
        }

        // Additional safety checks for null bytes and newlines
        guard !appName.contains("\0"),
              !appName.contains("\n"),
              !appName.contains("\r"),
              appName.count <= 100 else {  // Reasonable length limit
            print("Warning: Rejecting app name with invalid characters or excessive length")
            return nil
        }

        // Escape quotes in app name as additional safety
        let escapedName = appName.replacingOccurrences(of: "\\", with: "\\\\")
                                  .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            tell application "\(escapedName)"
                if (count of windows) > 0 then
                    return title of active tab of front window
                end if
            end tell
        """
        return runAppleScript(script)
    }

    private func getFirefoxTabTitle() -> String? {
        // Firefox doesn't have AppleScript support for tab titles
        // Fall back to window title which includes the tab title
        return currentWindowTitle
    }

    private func getArcTabTitle() -> String? {
        let script = """
            tell application "Arc"
                if (count of windows) > 0 then
                    return title of active tab of front window
                end if
            end tell
        """
        return runAppleScript(script)
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if error != nil {
            return nil
        }

        return result.stringValue
    }

    private func saveBrowserTabEvent(bundleId: String, tabTitle: String) {
        do {
            try DatabaseManager.shared.write { db in
                let data: [String: String] = [
                    "bundleId": bundleId,
                    "tabTitle": tabTitle
                ]
                let jsonData = try JSONEncoder().encode(data)
                let jsonString = jsonData.base64EncodedString()
                try db.execute(
                    sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                    arguments: [Date(), "browserTab", jsonString]
                )
            }
        } catch {
            print("Error saving browser tab event: \(error)")
        }
    }
}
