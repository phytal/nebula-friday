import Foundation
import Cocoa

class PermissionChecker {
    static func checkAccessibilityPermission() -> Bool {
        // Use AXIsProcessTrusted which is the most reliable method
        // This doesn't prompt but accurately returns the current state
        let trusted = AXIsProcessTrusted()

        print("Accessibility check: AXIsProcessTrusted = \(trusted)")

        // Note: AXIsProcessTrustedWithOptions can be unreliable, so we only use AXIsProcessTrusted
        // If the app was just granted permission, it may require an app restart to detect
        // This is a macOS limitation

        return trusted
    }

    static func checkScreenRecordingPermission() -> Bool {
        // IMPORTANT: Use CGPreflightScreenCaptureAccess() ONLY
        // Other APIs like SCShareableContent.canRecordScreen() trigger permission dialogs!
        // CGPreflightScreenCaptureAccess() returns true if granted, false if denied or not yet decided
        // It does NOT trigger a prompt, making it safe to call repeatedly
        return CGPreflightScreenCaptureAccess()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func requestScreenRecordingPermission() {
        // This will prompt the user
        CGRequestScreenCaptureAccess()
    }

    static func openPrivacySettings() {
        // Try different URLs for different macOS versions
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]

        for urlString in urls {
            if let url = URL(string: urlString),
               NSWorkspace.shared.open(url) {
                break
            }
        }
    }
}