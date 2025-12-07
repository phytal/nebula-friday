import Cocoa
import Foundation

// CLI version - can be used standalone without GUI
class NebulaTrackerCLI {
    static func runCLI() {
        let app = NebulaTrackerAppCLI()
        app.run()
    }
}

class NebulaTrackerAppCLI {
    private var windowTracker: WindowTracker?
    private var screenCapture: ScreenCapture?
    private var syncAgent: SyncAgent?
    private var eventLogger: EventLogger?
    private var shouldTerminate = false

    func run() {
        print("Nebula Tracker starting...")

        // Check for command line arguments
        handleCommandLineArgs()

        // Initialize configuration
        let config = Configuration.shared

        // Check if configured
        if !config.isConfigured() {
            print("⚠️  Configuration not complete!")
            print("Please edit the config file at:")
            print("~/Library/Application Support/NebulaTracker/config.json")
            print("Add your API endpoint and token, then restart the tracker.")
            showPermissionInstructions()
            exit(1)
        }

        // Check permissions
        if !checkPermissions() {
            showPermissionInstructions()
            exit(1)
        }

        // Initialize components
        setupComponents()

        // Set up signal handlers for graceful shutdown
        setupSignalHandlers()

        // Start run loop
        print("Nebula Tracker running...")
        print("Press Ctrl+C to stop")

        RunLoop.main.run()
    }

    private func handleCommandLineArgs() {
        let args = CommandLine.arguments

        if args.contains("--help") || args.contains("-h") {
            showHelp()
            exit(0)
        }

        if args.contains("--version") || args.contains("-v") {
            print("Nebula Tracker v1.0.0")
            exit(0)
        }

        if args.contains("--status") {
            showStatus()
            exit(0)
        }

        if args.contains("--permissions") {
            showPermissionInstructions()
            exit(0)
        }
    }

    private func setupComponents() {
        // Initialize logger first
        eventLogger = EventLogger.shared

        // Initialize tracking components
        if Configuration.shared.enableWindowTracking {
            windowTracker = WindowTracker.shared
            print("✓ Window tracking enabled")
        }

        if Configuration.shared.enableScreenCapture {
            screenCapture = ScreenCapture.shared
            print("✓ Screen capture enabled")
        }

        // Initialize sync agent
        syncAgent = SyncAgent.shared
        print("✓ Sync agent started")

        // Schedule cleanup tasks
        scheduleMaintenanceTasks()
    }

    private func scheduleMaintenanceTasks() {
        // Clean up old events and screenshots daily
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            print("Running maintenance tasks...")
            EventLogger.shared.deleteOldEvents(olderThanDays: 30)
            ScreenCapture.shared.cleanupOldScreenshots(olderThanDays: 7)
        }
    }

    private func checkPermissions() -> Bool {
        var hasPermissions = true

        // Check Accessibility permission
        if !AXIsProcessTrustedWithOptions(nil) {
            print("❌ Accessibility permission not granted")
            hasPermissions = false
        } else {
            print("✓ Accessibility permission granted")
        }

        // Check Screen Recording permission (macOS 11+)
        if #available(macOS 11.0, *) {
            if !CGPreflightScreenCaptureAccess() {
                print("❌ Screen Recording permission not granted")
                hasPermissions = false
            } else {
                print("✓ Screen Recording permission granted")
            }
        }

        return hasPermissions
    }

    private func showPermissionInstructions() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 PERMISSION SETUP REQUIRED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\nNebula Tracker needs the following permissions:")
        print("\n1. ACCESSIBILITY")
        print("   → System Preferences > Security & Privacy > Privacy > Accessibility")
        print("   → Click the lock to make changes")
        print("   → Add NebulaTracker to the list")
        print("\n2. SCREEN RECORDING")
        print("   → System Preferences > Security & Privacy > Privacy > Screen Recording")
        print("   → Click the lock to make changes")
        print("   → Add NebulaTracker to the list")
        print("\nAfter granting permissions, restart Nebula Tracker.")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    private func showHelp() {
        print("Nebula Tracker - Background Activity Monitor")
        print("\nUsage: nebula-tracker [options]")
        print("\nOptions:")
        print("  --help, -h         Show this help message")
        print("  --version, -v      Show version")
        print("  --status           Show current status and stats")
        print("  --permissions      Show permission setup instructions")
    }

    private func showStatus() {
        let stats = EventLogger.shared.getEventStats()
        print("Nebula Tracker Status")
        print("━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total Events: \(stats.total)")
        print("Synced: \(stats.synced)")
        print("Pending: \(stats.pending)")
        print("Configuration: \(Configuration.shared.isConfigured() ? "✓ Valid" : "❌ Invalid")")
    }

    private func setupSignalHandlers() {
        signal(SIGTERM) { _ in
            print("\nReceived SIGTERM, shutting down...")
            exit(0)
        }

        signal(SIGINT) { _ in
            print("\nReceived SIGINT, shutting down...")
            exit(0)
        }
    }
}