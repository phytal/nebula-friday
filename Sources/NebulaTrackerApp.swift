import SwiftUI
import Cocoa

@main
struct NebulaTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var permissionWindow: NSWindow?
    var configWindow: NSWindow?
    let permissionManager = PermissionManager()
    let trackerState = TrackerState()
    let configManager = ConfigurationManager()
    var eventMonitor: Any?
    private var menuBarUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar item
        setupMenuBar()

        // Setup event monitor for clicking outside popover
        setupEventMonitor()

        // Start periodic menu bar updates
        startMenuBarUpdates()

        // Listen for permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(permissionsChanged),
            name: Notification.Name("PermissionsChanged"),
            object: nil
        )

        // Check configuration and permissions after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkInitialSetup()
        }
    }

    @objc func permissionsChanged() {
        updateMenuBarIcon()
    }

    func checkInitialSetup() {
        if !permissionManager.hasAllPermissions() {
            showPermissionWindow()
        } else if !configManager.isConfigured() {
            showConfigWindow()
        } else {
            // Start tracking if everything is ready
            startTracking()
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func startMenuBarUpdates() {
        menuBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMenuBarIcon()
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else {
            print("No status bar button found!")
            return
        }

        // Try to use custom Nebula logo first
        if let nebulaIcon = createNebulaIcon() {
            button.image = nebulaIcon
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true  // Make it adapt to menu bar theme
            button.title = ""  // Clear any text
        } else {
            // Fallback to text if custom icon fails
            button.title = "N"  // Simple "N" for Nebula
        }

        print("Menu bar icon updated - tracking: \(trackerState.isTracking)")
    }

    func createNebulaIcon() -> NSImage? {
        // First try to load custom logo from file
        if let logoPath = Bundle.main.path(forResource: "nebula-logo", ofType: "png"),
           let image = NSImage(contentsOfFile: logoPath) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true  // Make it adapt to menu bar theme
            return image
        }

        // Create a simple static icon programmatically
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Simple "N" logo design
            NSColor.black.setFill()

            // Draw stylized "N" shape
            let path = NSBezierPath()

            // Left vertical line
            path.move(to: NSPoint(x: 4, y: 4))
            path.line(to: NSPoint(x: 4, y: 14))
            path.line(to: NSPoint(x: 6, y: 14))
            path.line(to: NSPoint(x: 6, y: 7))

            // Diagonal
            path.line(to: NSPoint(x: 12, y: 14))
            path.line(to: NSPoint(x: 14, y: 14))
            path.line(to: NSPoint(x: 14, y: 4))
            path.line(to: NSPoint(x: 12, y: 4))
            path.line(to: NSPoint(x: 12, y: 11))

            // Connect back
            path.line(to: NSPoint(x: 6, y: 4))
            path.close()

            path.fill()

            return true
        }

        image.isTemplate = true  // Make it adapt to dark/light mode
        return image
    }

    func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.closePopover()
            }
        }
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover.isShown {
                closePopover()
            } else {
                showPopover(button: button)
            }
        }
    }

    func showPopover(button: NSButton) {
        // Create fresh content view
        let contentView = MenuBarView(
            permissionManager: permissionManager,
            trackerState: trackerState,
            configManager: configManager,
            onRequestPermissions: { [weak self] in
                self?.closePopover()
                self?.showPermissionWindow()
            },
            onOpenConfig: { [weak self] in
                self?.closePopover()
                self?.showConfigWindow()
            },
            onToggleTracking: { [weak self] in
                self?.toggleTracking()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient

        // Update stats before showing
        trackerState.updateStats()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: false)
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func showPermissionWindow() {
        print("🪟 showPermissionWindow() called - permissionWindow is \(permissionWindow == nil ? "nil" : "already exists")")
        if permissionWindow == nil {
            print("   Creating new permission window...")
            // Set up callback for when all permissions are granted
            permissionManager.onAllPermissionsGranted = { [weak self] in
                // Auto-close window after a short delay to show success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.permissionWindow?.close()
                    self?.permissionWindow = nil
                    self?.updateMenuBarIcon()

                    // Check if we should show config or start tracking
                    if self?.configManager.isConfigured() == true {
                        self?.startTracking()
                    } else {
                        self?.showConfigWindow()
                    }
                }
            }

            let contentView = PermissionRequestView(
                permissionManager: permissionManager,
                onComplete: { [weak self] in
                    self?.permissionWindow?.close()
                    self?.permissionWindow = nil
                    self?.updateMenuBarIcon()
                    if self?.permissionManager.hasAllPermissions() == true && self?.configManager.isConfigured() == true {
                        self?.startTracking()
                    }
                }
            )

            permissionWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            permissionWindow?.contentView = NSHostingView(rootView: contentView)
            permissionWindow?.title = "Nebula Tracker Setup"
            permissionWindow?.center()
            permissionWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            permissionWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func showConfigWindow() {
        if configWindow == nil {
            let contentView = ConfigurationView(
                configManager: configManager,
                onSave: { [weak self] in
                    self?.configWindow?.close()
                    self?.configWindow = nil
                    self?.updateMenuBarIcon()
                    if self?.permissionManager.hasAllPermissions() == true {
                        self?.restartTracking()
                    }
                },
                onCancel: { [weak self] in
                    self?.configWindow?.close()
                    self?.configWindow = nil
                }
            )

            configWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            configWindow?.contentView = NSHostingView(rootView: contentView)
            configWindow?.title = "Nebula Tracker Configuration"
            configWindow?.center()
            configWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            configWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func toggleTracking() {
        if trackerState.isTracking {
            stopTracking()
        } else {
            startTracking()
        }
        updateMenuBarIcon()
    }

    func startTracking() {
        guard permissionManager.hasAllPermissions() && configManager.isConfigured() else { return }

        trackerState.startTracking()
        updateMenuBarIcon()

        // Note: Don't initialize heavy components here
        // They should be initialized lazily when actually needed
        print("Tracking started")
    }

    func stopTracking() {
        trackerState.stopTracking()
        updateMenuBarIcon()
        print("Tracking stopped")
    }

    func restartTracking() {
        if trackerState.isTracking {
            stopTracking()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startTracking()
            }
        }
    }
}

// MARK: - Configuration Manager
class ConfigurationManager: ObservableObject {
    @Published var apiEndpoint: String = ""
    @Published var apiToken: String = ""
    @Published var syncInterval: Int = 60
    @Published var captureInterval: Int = 30
    @Published var enableScreenshots: Bool = true
    @Published var enableWindowTracking: Bool = true

    private lazy var config = Configuration.shared

    init() {
        // Load configuration from the real config file (deferred to avoid crash during init)
        DispatchQueue.main.async { [weak self] in
            self?.loadConfiguration()
        }
    }

    func loadConfiguration() {
        // Load from the actual Configuration singleton
        print("📖 Loading configuration from disk...")
        self.apiEndpoint = self.config.apiEndpoint ?? "https://api.nebula.app/v1/memory-events"
        self.apiToken = self.config.apiToken ?? ""
        self.syncInterval = Int(self.config.syncInterval ?? 60.0)
        self.captureInterval = Int(self.config.captureInterval ?? 30.0)
        self.enableScreenshots = self.config.enableScreenCapture
        self.enableWindowTracking = self.config.enableWindowTracking
        print("✅ Configuration loaded: endpoint=\(self.apiEndpoint)")
    }

    func saveConfiguration() {
        print("💾 Saving configuration...")

        // Update the Configuration singleton
        config.apiEndpoint = apiEndpoint
        config.apiToken = apiToken
        config.syncInterval = Double(syncInterval)
        config.captureInterval = Double(captureInterval)
        config.enableScreenCapture = enableScreenshots
        config.enableWindowTracking = enableWindowTracking

        // Save to disk in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.config.saveConfig()
            DispatchQueue.main.async {
                print("✅ Configuration saved successfully")
            }
        }
    }

    func isConfigured() -> Bool {
        return config.isConfigured()
    }
}

// MARK: - Permission Manager
class PermissionManager: ObservableObject {
    @Published var hasAccessibility = false
    @Published var hasScreenRecording = false
    @Published var lastChecked = Date()
    @Published var isRequestingAccessibility = false
    @Published var isRequestingScreenRecording = false
    private var checkTimer: Timer?
    private let permissionState = PermissionState.shared
    var onAllPermissionsGranted: (() -> Void)?

    init() {
        // Check permissions WITHOUT prompting
        checkPermissions()
        // Start monitoring
        startMonitoring()
    }

    func checkPermissions() {
        let previousAccessibility = hasAccessibility
        let previousScreenRecording = hasScreenRecording

        // Use the better permission checker
        let accessibility = PermissionChecker.checkAccessibilityPermission()
        let screenRecording = PermissionChecker.checkScreenRecordingPermission()

        print("Permission check result - Accessibility: \(accessibility), Screen Recording: \(screenRecording)")

        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let changed = (self.hasAccessibility != accessibility) || (self.hasScreenRecording != screenRecording)

            self.hasAccessibility = accessibility
            self.hasScreenRecording = screenRecording
            self.lastChecked = Date()

            // Update the menu bar icon if permissions changed
            if changed {
                NotificationCenter.default.post(name: Notification.Name("PermissionsChanged"), object: nil)
            }

            // Detect when permissions change from false to true
            if !previousAccessibility && accessibility {
                print("✅ Accessibility permission granted!")
                NSSound.beep()  // Play system sound
            }

            if !previousScreenRecording && screenRecording {
                print("✅ Screen Recording permission granted!")
                NSSound.beep()  // Play system sound
            }

            // If all permissions are now granted and weren't before
            if self.hasAllPermissions() && (!previousAccessibility || !previousScreenRecording) {
                print("🎉 All permissions granted!")
                self.onAllPermissionsGranted?()
            }
        }
    }

    func hasAllPermissions() -> Bool {
        return hasAccessibility && hasScreenRecording
    }

    func requestAccessibility() {
        print("🔔 requestAccessibility() called")
        print("   isRequestingAccessibility: \(isRequestingAccessibility)")
        print("   hasRequestedAccessibility (UserDefaults): \(permissionState.hasRequestedAccessibility)")

        // Prevent multiple simultaneous requests
        guard !isRequestingAccessibility else {
            print("⚠️ Accessibility permission request already in progress, ignoring")
            return
        }

        // Only request once per app lifetime (persists across sessions)
        if !permissionState.hasRequestedAccessibility {
            isRequestingAccessibility = true
            permissionState.hasRequestedAccessibility = true
            permissionState.lastPromptDate = Date()

            print("🔐 Requesting Accessibility permission...")
            PermissionChecker.requestAccessibilityPermission()

            // Check more frequently after request
            startIntenseMonitoring()

            // Reset the flag after a delay (in case dialog was dismissed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.isRequestingAccessibility = false
            }
        } else {
            print("ℹ️ Accessibility permission already requested, opening System Preferences")
            // If already requested, just open settings
            openSystemPreferences()
        }
    }

    func requestScreenRecording() {
        print("🔔 requestScreenRecording() called")
        print("   isRequestingScreenRecording: \(isRequestingScreenRecording)")
        print("   hasRequestedScreenRecording (UserDefaults): \(permissionState.hasRequestedScreenRecording)")

        // Prevent multiple simultaneous requests
        guard !isRequestingScreenRecording else {
            print("⚠️ Screen Recording permission request already in progress, ignoring")
            return
        }

        // Only request once per app lifetime (persists across sessions)
        if !permissionState.hasRequestedScreenRecording {
            isRequestingScreenRecording = true
            permissionState.hasRequestedScreenRecording = true
            permissionState.lastPromptDate = Date()

            print("🔐 Requesting Screen Recording permission...")
            PermissionChecker.requestScreenRecordingPermission()

            // Check more frequently after request
            startIntenseMonitoring()

            // Reset the flag after a delay (in case dialog was dismissed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.isRequestingScreenRecording = false
            }
        } else {
            print("ℹ️ Screen Recording permission already requested, opening System Preferences")
            // If already requested, just open settings
            openSystemPreferences()
        }
    }

    func openSystemPreferences() {
        print("⚙️ Opening System Preferences...")
        PermissionChecker.openPrivacySettings()
        // Check more frequently when preferences open
        startIntenseMonitoring()
    }

    func startMonitoring() {
        stopMonitoring()
        // Check every second for changes
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    func startIntenseMonitoring() {
        stopMonitoring()
        // Check every 0.5 seconds for 30 seconds after permission request
        var checkCount = 0
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            self?.checkPermissions()
            checkCount += 1

            // After 60 checks (30 seconds), go back to normal monitoring
            if checkCount > 60 {
                self?.startMonitoring()
            }
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}

// MARK: - Tracker State
class TrackerState: ObservableObject {
    @Published var isTracking = false
    @Published var eventCount = 0
    @Published var pendingSync = 0
    @Published var lastSync: Date?
    @Published var lastEvent: Date?

    func startTracking() {
        isTracking = true
        updateStats()
    }

    func stopTracking() {
        isTracking = false
    }

    func updateStats() {
        // Update stats without blocking
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Simulate getting stats
            let count = Int.random(in: 0...100)
            let pending = Int.random(in: 0...10)

            DispatchQueue.main.async {
                self?.eventCount = count
                self?.pendingSync = pending
                if count > 0 {
                    self?.lastEvent = Date()
                }
            }
        }
    }
}

// MARK: - Views
struct MenuBarView: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var trackerState: TrackerState
    @ObservedObject var configManager: ConfigurationManager
    let onRequestPermissions: () -> Void
    let onOpenConfig: () -> Void
    let onToggleTracking: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Nebula Tracker")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            Divider()

            // Status
            StatusRow(label: "Status", value: statusText, color: statusColor)

            if trackerState.isTracking {
                StatusRow(label: "Events", value: "\(trackerState.eventCount)", color: .primary)
                if trackerState.pendingSync > 0 {
                    StatusRow(label: "Pending", value: "\(trackerState.pendingSync)", color: .orange)
                }
            }

            Divider()

            // Controls
            VStack(spacing: 8) {
                Button(action: onToggleTracking) {
                    Label(
                        trackerState.isTracking ? "Pause" : "Start",
                        systemImage: trackerState.isTracking ? "pause.circle" : "play.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canTrack)

                Button(action: onOpenConfig) {
                    Label("Configuration", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !permissionManager.hasAllPermissions() {
                    Button(action: onRequestPermissions) {
                        Label("Permissions", systemImage: "shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 300)
    }

    var canTrack: Bool {
        permissionManager.hasAllPermissions() && configManager.isConfigured()
    }

    var statusColor: Color {
        if !permissionManager.hasAllPermissions() {
            return .orange
        } else if !configManager.isConfigured() {
            return .yellow
        } else if trackerState.isTracking {
            return .green
        } else {
            return .gray
        }
    }

    var statusText: String {
        if !permissionManager.hasAllPermissions() {
            return "Permissions Required"
        } else if !configManager.isConfigured() {
            return "Configuration Required"
        } else if trackerState.isTracking {
            return "Tracking Active"
        } else {
            return "Tracking Paused"
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct ConfigurationView: View {
    @ObservedObject var configManager: ConfigurationManager
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var showingSaveConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.top, 20)

            Divider()

            // Configuration fields
            Form {
                Section("API Settings") {
                    TextField("API Endpoint", text: $configManager.apiEndpoint)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API Token", text: $configManager.apiToken)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Intervals") {
                    Picker("Sync Interval", selection: $configManager.syncInterval) {
                        Text("30 sec").tag(30)
                        Text("1 min").tag(60)
                        Text("2 min").tag(120)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Enable Screenshots", isOn: $configManager.enableScreenshots)
                    Toggle("Enable Window Tracking", isOn: $configManager.enableWindowTracking)
                }
            }
            .padding()

            Spacer()

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save") {
                    configManager.saveConfiguration()
                    showingSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onSave()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
}

struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManager
    let onComplete: () -> Void
    @State private var showingInstructions = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 30)

            Text("Permission Setup")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Nebula Tracker needs permissions to monitor activity")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                PermissionStep(
                    title: "Accessibility",
                    description: "Detect active windows",
                    icon: "hand.tap",
                    isGranted: permissionManager.hasAccessibility,
                    isRequesting: permissionManager.isRequestingAccessibility,
                    action: {
                        permissionManager.requestAccessibility()
                        showingInstructions = true
                    }
                )

                PermissionStep(
                    title: "Screen Recording",
                    description: "Capture screenshots",
                    icon: "rectangle.dashed.badge.record",
                    isGranted: permissionManager.hasScreenRecording,
                    isRequesting: permissionManager.isRequestingScreenRecording,
                    action: {
                        permissionManager.requestScreenRecording()
                        showingInstructions = true
                    }
                )
            }
            .padding(.horizontal, 40)

            if showingInstructions {
                VStack(spacing: 4) {
                    Text("⚠️ After granting permissions:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Screen Recording: Should be detected immediately")
                        .font(.caption)
                    Text("Accessibility: May require app restart to detect")
                        .font(.caption)
                    Text("(This is a macOS limitation)")
                        .font(.caption2)
                        .italic()
                }
                .foregroundColor(.orange)
                .padding(.horizontal)
            }

            Spacer()

            HStack {
                Button("Open Settings") {
                    permissionManager.openSystemPreferences()
                }
                .buttonStyle(.plain)

                Spacer()

                if permissionManager.hasAllPermissions() {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All Permissions Granted!")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding(.trailing)

                    Button("Continue") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Checking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(permissionManager.lastChecked.timeIntervalSinceNow > -2 ? 1 : 0)

                    Button("Skip") {
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            permissionManager.startIntenseMonitoring()
        }
        .onDisappear {
            permissionManager.startMonitoring()
        }
    }
}

struct PermissionStep: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let isRequesting: Bool
    let action: () -> Void
    @State private var showCheckmark = false
    @State private var animateGrant = false

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(isGranted ? .green : .blue)
                .frame(width: 40)
                .scaleEffect(animateGrant ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateGrant)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ZStack {
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                        .scaleEffect(showCheckmark ? 1.0 : 0.3)
                        .opacity(showCheckmark ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                } else if isRequesting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 60)
                } else {
                    Button("Grant", action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isRequesting)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isGranted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .onChange(of: isGranted) { newValue in
            if newValue {
                // Animate the checkmark appearance
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showCheckmark = true
                    animateGrant = true
                }
                // Reset animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animateGrant = false
                }
            }
        }
        .onAppear {
            if isGranted {
                showCheckmark = true
            }
        }
    }
}

// Helper
class NSHostingController<Content: View>: NSViewController {
    override func loadView() {
        self.view = NSHostingView(rootView: rootView)
    }

    init(rootView: Content) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let rootView: Content
}