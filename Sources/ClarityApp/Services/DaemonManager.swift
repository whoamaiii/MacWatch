import Foundation
import Combine

/// Manages the ClarityDaemon process lifecycle
@MainActor
public final class DaemonManager: ObservableObject {
    public static let shared = DaemonManager()

    @Published public private(set) var isRunning = false
    @Published public private(set) var lastError: String?

    private var daemonProcess: Process?
    private var healthCheckTimer: Timer?

    private init() {
        // Check initial status
        checkDaemonStatus()

        // Start health monitoring
        startHealthMonitoring()
    }

    deinit {
        healthCheckTimer?.invalidate()
    }

    // MARK: - Public API

    /// Start the daemon if not already running
    public func startDaemon() {
        guard !isRunning else {
            print("[DaemonManager] Daemon already running")
            return
        }

        lastError = nil

        // Find the daemon executable
        guard let daemonPath = findDaemonExecutable() else {
            lastError = "Could not find ClarityDaemon executable"
            print("[DaemonManager] \(lastError!)")
            return
        }

        print("[DaemonManager] Starting daemon from: \(daemonPath)")

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: daemonPath)
            process.arguments = []

            // Set up pipes for output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Handle process termination
            process.terminationHandler = { [weak self] proc in
                Task { @MainActor in
                    self?.handleDaemonTermination(exitCode: proc.terminationStatus)
                }
            }

            try process.run()
            daemonProcess = process
            isRunning = true

            print("[DaemonManager] Daemon started with PID: \(process.processIdentifier)")
        } catch {
            lastError = "Failed to start daemon: \(error.localizedDescription)"
            print("[DaemonManager] \(lastError!)")
        }
    }

    /// Stop the daemon
    public func stopDaemon() {
        if let process = daemonProcess, process.isRunning {
            process.terminate()
            daemonProcess = nil
            isRunning = false
            print("[DaemonManager] Daemon stopped via process reference")
        } else {
            // Kill any running daemon by name
            killExistingDaemon()
            isRunning = false
        }
    }

    /// Restart the daemon
    public func restartDaemon() {
        stopDaemon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                self.startDaemon()
            }
        }
    }

    // MARK: - Private Methods

    private func findDaemonExecutable() -> String? {
        // Check common locations in order of preference

        // 1. Check if running from Xcode - use build directory
        let buildDir = FileManager.default.currentDirectoryPath + "/.build/debug/ClarityDaemon"
        if FileManager.default.isExecutableFile(atPath: buildDir) {
            return buildDir
        }

        // 2. Check relative to the app bundle
        if let bundlePath = Bundle.main.bundlePath as String? {
            let appDir = (bundlePath as NSString).deletingLastPathComponent
            let daemonInAppDir = appDir + "/ClarityDaemon"
            if FileManager.default.isExecutableFile(atPath: daemonInAppDir) {
                return daemonInAppDir
            }
        }

        // 3. Check in the same directory as the running binary
        if let executablePath = Bundle.main.executablePath {
            let execDir = (executablePath as NSString).deletingLastPathComponent
            let daemonPath = execDir + "/ClarityDaemon"
            if FileManager.default.isExecutableFile(atPath: daemonPath) {
                return daemonPath
            }
        }

        // 4. Check common development paths
        let devPaths = [
            NSHomeDirectory() + "/Desktop/game/clarity/Clarity/.build/debug/ClarityDaemon",
            "/usr/local/bin/ClarityDaemon",
            "/opt/clarity/ClarityDaemon"
        ]

        for path in devPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func checkDaemonStatus() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "ClarityDaemon"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            isRunning = task.terminationStatus == 0
        } catch {
            isRunning = false
        }
    }

    private func killExistingDaemon() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-x", "ClarityDaemon"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            print("[DaemonManager] Killed existing daemon processes")
        } catch {
            // Ignore errors - daemon may not be running
        }
    }

    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDaemonStatus()
            }
        }
    }

    private func handleDaemonTermination(exitCode: Int32) {
        daemonProcess = nil
        isRunning = false

        if exitCode != 0 {
            lastError = "Daemon exited with code \(exitCode)"
            print("[DaemonManager] \(lastError!)")

            // Auto-restart after unexpected termination
            if exitCode != 0 && exitCode != 15 { // 15 = SIGTERM (normal stop)
                print("[DaemonManager] Attempting auto-restart in 2 seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Task { @MainActor in
                        self.startDaemon()
                    }
                }
            }
        }
    }
}
