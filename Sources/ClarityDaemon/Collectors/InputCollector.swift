import Foundation
import CoreGraphics
import AppKit
import ClarityShared

/// Collects keyboard and mouse input events
final class InputCollector {
    private let statsRepo = StatsRepository()
    private let appRepo = AppRepository()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Current minute bucket
    private var currentMinute: Int64 = 0
    private var keystrokeBuffer: [Int64: Int] = [:]  // appId -> count
    private var clickBuffer: [Int64: Int] = [:]
    private var scrollBuffer: [Int64: Int] = [:]

    // For tracking current app
    private var currentAppId: Int64?

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
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

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
        updateCurrentMinute()
        updateCurrentApp()

        guard let appId = currentAppId else { return }

        switch type {
        case .keyDown:
            handleKeyDown(event: event, appId: appId)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            handleMouseClick(event: event, appId: appId, type: type)

        case .scrollWheel:
            handleScroll(event: event, appId: appId)

        default:
            break
        }
    }

    private func handleKeyDown(event: CGEvent, appId: Int64) {
        // Ignore auto-repeat
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return
        }

        keystrokeBuffer[appId, default: 0] += 1
    }

    private func handleMouseClick(event: CGEvent, appId: Int64, type: CGEventType) {
        clickBuffer[appId, default: 0] += 1
    }

    private func handleScroll(event: CGEvent, appId: Int64) {
        let deltaY = abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let deltaX = abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        scrollBuffer[appId, default: 0] += Int(deltaY + deltaX)
    }

    // MARK: - Buffer Management

    private func updateCurrentMinute() {
        let minute = Int64(Date().timeIntervalSince1970) / 60 * 60

        if minute != currentMinute {
            // New minute, flush old data
            flushBuffers()
            currentMinute = minute
        }
    }

    private func updateCurrentApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier,
           let name = frontApp.localizedName {
            do {
                let app = try appRepo.findOrCreate(bundleId: bundleId, name: name)
                currentAppId = app.id
            } catch {
                // Silently fail - will retry next event
            }
        }
    }

    private func flushBuffers() {
        guard currentMinute > 0 else { return }

        // Combine keystroke buffer
        for (appId, keystrokes) in keystrokeBuffer where keystrokes > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: currentMinute,
                    appId: appId,
                    keystrokes: keystrokes
                )
            } catch {
                print("Error flushing keystrokes: \(error)")
            }
        }

        // Combine click buffer
        for (appId, clicks) in clickBuffer where clicks > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: currentMinute,
                    appId: appId,
                    clicks: clicks
                )
            } catch {
                print("Error flushing clicks: \(error)")
            }
        }

        // Combine scroll buffer
        for (appId, scroll) in scrollBuffer where scroll > 0 {
            do {
                try statsRepo.recordMinuteStat(
                    timestamp: currentMinute,
                    appId: appId,
                    scrollDistance: scroll
                )
            } catch {
                print("Error flushing scroll: \(error)")
            }
        }

        // Clear buffers
        keystrokeBuffer.removeAll()
        clickBuffer.removeAll()
        scrollBuffer.removeAll()
    }
}
