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
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    // Auto-restart with exponential backoff
    private var restartAttempts = 0
    private let maxRestartAttempts = 5
    private var lastRestartTime: Date?

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

            // Clean up old pipe handlers before creating new ones
            cleanupPipes()

            // Set up pipes for output
            let newOutputPipe = Pipe()
            let newErrorPipe = Pipe()
            process.standardOutput = newOutputPipe
            process.standardError = newErrorPipe

            // Store references for cleanup
            self.outputPipe = newOutputPipe
            self.errorPipe = newErrorPipe

            // Drain output to avoid blocking if buffers fill
            newOutputPipe.fileHandleForReading.readabilityHandler = { handle in
                _ = handle.availableData
            }
            newErrorPipe.fileHandleForReading.readabilityHandler = { handle in
                _ = handle.availableData
            }

            // Handle process termination
            process.terminationHandler = { [weak self] proc in
                Task { @MainActor in
                    self?.cleanupPipes()
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
        // Use URL API for proper path handling (handles spaces and special characters)

        // 1. Check if running from Xcode - use build directory
        let currentDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let buildDirURL = currentDirURL.appendingPathComponent(".build/debug/ClarityDaemon")
        if FileManager.default.isExecutableFile(atPath: buildDirURL.path) {
            return buildDirURL.path
        }

        // 2. Check relative to the app bundle
        let bundleURL = Bundle.main.bundleURL
        let appDirURL = bundleURL.deletingLastPathComponent()
        let daemonInAppDirURL = appDirURL.appendingPathComponent("ClarityDaemon")
        if FileManager.default.isExecutableFile(atPath: daemonInAppDirURL.path) {
            return daemonInAppDirURL.path
        }

        // 3. Check in the same directory as the running binary
        if let executableURL = Bundle.main.executableURL {
            let execDirURL = executableURL.deletingLastPathComponent()
            let daemonURL = execDirURL.appendingPathComponent("ClarityDaemon")
            if FileManager.default.isExecutableFile(atPath: daemonURL.path) {
                return daemonURL.path
            }
        }

        // 4. Check common development paths
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let devPaths = [
            homeURL.appendingPathComponent("Desktop/game/clarity/Clarity/.build/debug/ClarityDaemon").path,
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
        // Invalidate existing timer to prevent accumulation
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDaemonStatus()
            }
        }
    }

    private func handleDaemonTermination(exitCode: Int32) {
        daemonProcess = nil
        isRunning = false

        if exitCode == 0 || exitCode == 15 { // Normal exit or SIGTERM
            restartAttempts = 0
            return
        }

        lastError = "Daemon exited with code \(exitCode)"
        print("[DaemonManager] \(lastError!)")

        // Reset restart counter if enough time has passed (5 minutes)
        if let lastRestart = lastRestartTime,
           Date().timeIntervalSince(lastRestart) > 300 {
            restartAttempts = 0
        }

        // Check if we should auto-restart
        guard restartAttempts < maxRestartAttempts else {
            lastError = "Daemon crashed \(maxRestartAttempts) times. Manual restart required."
            print("[DaemonManager] \(lastError!)")
            return
        }

        // Exponential backoff: 2s, 4s, 8s, 16s, 32s
        let delay = pow(2.0, Double(restartAttempts + 1))
        restartAttempts += 1
        lastRestartTime = Date()

        print("[DaemonManager] Restart attempt \(restartAttempts)/\(maxRestartAttempts) in \(Int(delay)) seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor in
                self?.startDaemon()
            }
        }
    }

    /// Reset restart counter (call after successful user-initiated start)
    public func resetRestartCounter() {
        restartAttempts = 0
        lastRestartTime = nil
    }

    /// Clean up pipe handlers to prevent stale callbacks
    private func cleanupPipes() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
    }
}
