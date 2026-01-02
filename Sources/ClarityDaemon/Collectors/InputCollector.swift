import Foundation
import CoreGraphics
import AppKit
import ClarityShared

/// Collects keyboard and mouse input events
final class InputCollector {
    private let statsRepo = StatsRepository()
    private let appRepo = AppRepository()
    private let settings = TrackingSettings.shared

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Lock for thread-safe buffer access
    private let bufferLock = NSLock()

    // Current minute bucket (protected by bufferLock)
    private var currentMinute: Int64 = 0
    private var keystrokeBuffer: [Int64: Int] = [:]  // appId -> count
    private var clickBuffer: [Int64: Int] = [:]
    private var scrollBuffer: [Int64: Int] = [:]
    private var mouseDistanceBuffer: [Int64: Int] = [:]
    private var idleSecondsBuffer: [Int64: Int] = [:]
    private var keycodeBuffer: [Int: Int] = [:]       // keyCode -> count
    private var clickPositions: [[Int]] = []          // [[x, y], ...] for heatmap

    // For tracking current app (protected by bufferLock)
    private var currentAppId: Int64?
    private var lastMouseLocation: CGPoint?
    private var lastInputTime: Date = Date()

    // App ID cache to avoid database lookups while holding lock
    private var appIdCache: [String: Int64] = [:]
    private var lastCachedBundleId: String?

    private var flushTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        setupEventTap()
        setupFlushTimer()
        print("InputCollector started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        flushTimer?.invalidate()
        flushTimer = nil

        // Final flush
        flushBuffers()

        print("InputCollector stopped")
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        // Events to capture
        let eventTypes: [CGEventType] = [
            .keyDown,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << type.rawValue)
        }

        // Create event tap
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let collector = Unmanaged<InputCollector>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = collector.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return nil
                }
                collector.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: refcon
        )

        guard let tap = eventTap else {
            print("ERROR: Failed to create event tap. Check accessibility permissions.")
            return
        }

        // Add to run loop
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func setupFlushTimer() {
        // Flush buffers every second
        flushTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.flushBuffers()
        }
    }

    // MARK: - Event Handling

    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard settings.inputTrackingEnabled else { return }

        var pendingFlush: (Int64, [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int: Int], [[Int]])?

        bufferLock.lock()

        // Check if minute changed and prepare flush data
        let minute = (Int64(Date().timeIntervalSince1970) / 60) * 60
        if minute != currentMinute && currentMinute > 0 {
            // Capture data to flush before starting new minute
            pendingFlush = (
                currentMinute,
                keystrokeBuffer,
                clickBuffer,
                scrollBuffer,
                mouseDistanceBuffer,
                idleSecondsBuffer,
                keycodeBuffer,
                clickPositions
            )
            keystrokeBuffer.removeAll()
            clickBuffer.removeAll()
            scrollBuffer.removeAll()
            mouseDistanceBuffer.removeAll()
            idleSecondsBuffer.removeAll()
            keycodeBuffer.removeAll()
            clickPositions.removeAll()
        }
        currentMinute = minute

        updateCurrentAppUnsafe()
        lastInputTime = Date()

        guard let appId = currentAppId else {
            bufferLock.unlock()
            // Flush outside lock if needed
            if let flush = pendingFlush {
                flushToDatabase(
                    minute: flush.0,
                    keystrokes: flush.1,
                    clicks: flush.2,
                    scroll: flush.3,
                    mouseDistance: flush.4,
                    idleSeconds: flush.5,
                    keycodes: flush.6,
                    positions: flush.7
                )
            }
            return
        }

        switch type {
        case .keyDown:
            handleKeyDownUnsafe(event: event, appId: appId)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            handleMouseClickUnsafe(event: event, appId: appId, type: type)

        case .scrollWheel:
            handleScrollUnsafe(event: event, appId: appId)

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            handleMouseMoveUnsafe(event: event, appId: appId)

        default:
            break
        }

        bufferLock.unlock()

        // Flush outside lock if needed
        if let flush = pendingFlush {
            flushToDatabase(
                minute: flush.0,
                keystrokes: flush.1,
                clicks: flush.2,
                scroll: flush.3,
                mouseDistance: flush.4,
                idleSeconds: flush.5,
                keycodes: flush.6,
                positions: flush.7
            )
        }
    }

    // MARK: - Unsafe Methods (must be called with bufferLock held)

    private func handleKeyDownUnsafe(event: CGEvent, appId: Int64) {
        // Ignore auto-repeat
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return
        }

        keystrokeBuffer[appId, default: 0] += 1

        // Track key code for heatmap
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        keycodeBuffer[keyCode, default: 0] += 1
    }

    private var clickPositionLimitWarned = false

    private func handleMouseClickUnsafe(event: CGEvent, appId: Int64, type: CGEventType) {
        clickBuffer[appId, default: 0] += 1

        // Capture click position for heatmap (normalized to screen)
        let location = event.location
        let x = Int(location.x)
        let y = Int(location.y)
        // Limit click positions to prevent unbounded growth (10k per flush cycle)
        if clickPositions.count < 10000 {
            clickPositions.append([x, y])
        } else if !clickPositionLimitWarned {
            clickPositionLimitWarned = true
            print("Warning: Click position buffer full (10000). Some positions will be dropped until next flush.")
        }
    }

    private func handleScrollUnsafe(event: CGEvent, appId: Int64) {
        let deltaY = abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let deltaX = abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        scrollBuffer[appId, default: 0] += Int(deltaY + deltaX)
    }

    private func handleMouseMoveUnsafe(event: CGEvent, appId: Int64) {
        let location = event.location
        if let last = lastMouseLocation {
            let dx = location.x - last.x
            let dy = location.y - last.y
            let distance = Int((dx * dx + dy * dy).squareRoot())
            if distance > 0 {
                mouseDistanceBuffer[appId, default: 0] += distance
            }
        }
        lastMouseLocation = location
    }

    private func updateCurrentAppUnsafe() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let name = frontApp.localizedName else {
            return
        }

        // Check cache first to avoid database call while holding lock
        if let cachedId = appIdCache[bundleId] {
            currentAppId = cachedId
            lastCachedBundleId = bundleId
            return
        }

        // Only do database lookup if not in cache
        // Note: This still happens with lock held, but only once per app
        do {
            let app = try appRepo.findOrCreate(bundleId: bundleId, name: name)
            if let appId = app.id {
                appIdCache[bundleId] = appId
                currentAppId = appId
                lastCachedBundleId = bundleId
            }
        } catch {
            // Silently fail - will retry next event
        }
    }

    // MARK: - Buffer Management

    private func flushBuffers() {
        let flushes = snapshotBuffers()
        for flush in flushes {
            flushToDatabase(
                minute: flush.0,
                keystrokes: flush.1,
                clicks: flush.2,
                scroll: flush.3,
                mouseDistance: flush.4,
                idleSeconds: flush.5,
                keycodes: flush.6,
                positions: flush.7
            )
        }
    }

    private func snapshotBuffers() -> [(Int64, [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int: Int], [[Int]])] {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let now = Date()
        let minute = (Int64(now.timeIntervalSince1970) / 60) * 60
        var flushes: [(Int64, [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int64: Int], [Int: Int], [[Int]])] = []

        // Handle minute boundary crossing - flush previous minute's data
        if minute != currentMinute && currentMinute > 0 {
            // Only append if there's actual data to flush
            let hasData = !keystrokeBuffer.isEmpty || !clickBuffer.isEmpty ||
                          !scrollBuffer.isEmpty || !mouseDistanceBuffer.isEmpty ||
                          !keycodeBuffer.isEmpty || !clickPositions.isEmpty

            if hasData {
                flushes.append((
                    currentMinute,
                    keystrokeBuffer,
                    clickBuffer,
                    scrollBuffer,
                    mouseDistanceBuffer,
                    idleSecondsBuffer,
                    keycodeBuffer,
                    clickPositions
                ))

                // Clear buffers after capturing
                keystrokeBuffer.removeAll()
                clickBuffer.removeAll()
                scrollBuffer.removeAll()
                mouseDistanceBuffer.removeAll()
                idleSecondsBuffer.removeAll()
                keycodeBuffer.removeAll()
                clickPositions.removeAll()
                clickPositionLimitWarned = false  // Reset warning for next cycle
            }

            currentMinute = minute
        } else if currentMinute == 0 {
            currentMinute = minute
        }

        updateCurrentAppUnsafe()

        // Track idle time
        if let appId = currentAppId, now.timeIntervalSince(lastInputTime) >= 1 {
            idleSecondsBuffer[appId, default: 0] += 1
        }

        return flushes
    }

    private func flushToDatabase(
        minute: Int64,
        keystrokes: [Int64: Int],
        clicks: [Int64: Int],
        scroll: [Int64: Int],
        mouseDistance: [Int64: Int],
        idleSeconds: [Int64: Int],
        keycodes: [Int: Int],
        positions: [[Int]]
    ) {
        // Flush keystroke buffer
        for (appId, count) in keystrokes where count > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: minute,
                    appId: appId,
                    keystrokes: count
                )
            } catch {
                print("Error flushing keystrokes: \(error)")
            }
        }

        // Flush click buffer
        for (appId, count) in clicks where count > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: minute,
                    appId: appId,
                    clicks: count
                )
            } catch {
                print("Error flushing clicks: \(error)")
            }
        }

        // Flush scroll buffer
        for (appId, distance) in scroll where distance > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: minute,
                    appId: appId,
                    scrollDistance: distance
                )
            } catch {
                print("Error flushing scroll: \(error)")
            }
        }

        // Flush mouse distance buffer
        for (appId, distance) in mouseDistance where distance > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: minute,
                    appId: appId,
                    mouseDistance: distance
                )
            } catch {
                print("Error flushing mouse distance: \(error)")
            }
        }

        // Flush idle seconds buffer
        for (appId, seconds) in idleSeconds where seconds > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: minute,
                    appId: appId,
                    idleSeconds: seconds
                )
            } catch {
                print("Error flushing idle seconds: \(error)")
            }
        }

        // Save keycode frequency as raw event (use minute timestamp, not current time)
        let minuteDate = Date(timeIntervalSince1970: TimeInterval(minute))
        if !keycodes.isEmpty {
            do {
                try DatabaseManager.shared.write { db in
                    let jsonData = try JSONEncoder().encode(keycodes)
                    let jsonString = jsonData.base64EncodedString()
                    try db.execute(
                        sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                        arguments: [minuteDate, "keycodeFrequency", jsonString]
                    )
                }
            } catch {
                print("Error flushing keycode frequency: \(error)")
            }
        }

        // Save click positions as raw event (use minute timestamp, not current time)
        if !positions.isEmpty {
            do {
                try DatabaseManager.shared.write { db in
                    let jsonData = try JSONEncoder().encode(positions)
                    let jsonString = jsonData.base64EncodedString()
                    try db.execute(
                        sql: "INSERT INTO raw_events (timestamp, eventType, dataJson) VALUES (?, ?, ?)",
                        arguments: [minuteDate, "clickPositions", jsonString]
                    )
                }
            } catch {
                print("Error flushing click positions: \(error)")
            }
        }
    }
}
