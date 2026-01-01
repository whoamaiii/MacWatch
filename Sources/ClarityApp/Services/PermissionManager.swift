import Foundation
import AppKit

/// Manages system permissions required by Clarity
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var hasAccessibilityPermission = false
    @Published public private(set) var isCheckingPermissions = false

    private var permissionCheckTimer: Timer?

    private init() {
        checkPermissions()
        startPermissionMonitoring()
    }

    deinit {
        permissionCheckTimer?.invalidate()
    }

    // MARK: - Public API

    /// Check all required permissions
    public func checkPermissions() {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }

        // Check accessibility permission (required for input and window tracking)
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    /// Request accessibility permission (opens System Settings)
    public func requestAccessibilityPermission() {
        // This will prompt the user if not already trusted
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        hasAccessibilityPermission = trusted

        if !trusted {
            // Open System Settings to the Accessibility pane
            openAccessibilitySettings()
        }
    }

    /// Open System Settings to Accessibility pane
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Check if all required permissions are granted
    public var allPermissionsGranted: Bool {
        hasAccessibilityPermission
    }

    // MARK: - Private Methods

    private func startPermissionMonitoring() {
        // Check permissions periodically in case user grants them in System Settings
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }
}
