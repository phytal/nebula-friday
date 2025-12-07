import Cocoa
import Foundation

class WindowTracker {
    static let shared = WindowTracker()
    private var lastActiveApp: String?
    private var lastWindowTitle: String?
    private var timer: Timer?

    init() {
        // Start monitoring workspace notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(windowChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Also poll for window title changes every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.checkActiveWindow()
        }
    }

    @objc func windowChanged(notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let appName = app.localizedName ?? "Unknown"

            // Only log if app actually changed
            if appName != lastActiveApp {
                lastActiveApp = appName
                print("Active app changed to: \(appName)")

                EventLogger.shared.logEvent(
                    type: .windowChange,
                    appName: appName,
                    windowTitle: getActiveWindowTitle(),
                    screenshotPath: nil
                )

                // Capture screenshot on significant change
                ScreenCapture.shared.captureIfChanged()
            }
        }
    }

    func checkActiveWindow() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let currentTitle = getActiveWindowTitle()
        let appName = frontApp.localizedName ?? "Unknown"

        // Check if window title changed within the same app
        if currentTitle != lastWindowTitle && currentTitle != nil {
            lastWindowTitle = currentTitle
            print("Window title changed to: \(currentTitle ?? "None")")

            EventLogger.shared.logEvent(
                type: .windowChange,
                appName: appName,
                windowTitle: currentTitle,
                screenshotPath: nil
            )

            // Capture screenshot on title change
            ScreenCapture.shared.captureIfChanged()
        }
    }

    private func getActiveWindowTitle() -> String? {
        // This requires Accessibility permissions
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let pid = frontApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue)

        guard result == .success, let window = windowValue else { return nil }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue)

        guard titleResult == .success, let title = titleValue as? String else { return nil }

        return title
    }

    deinit {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}