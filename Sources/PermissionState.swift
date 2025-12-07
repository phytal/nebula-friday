import Foundation

// Persistent storage for permission request state
class PermissionState {
    static let shared = PermissionState()

    private let defaults = UserDefaults.standard
    private let accessibilityRequestedKey = "NebulaTracker.AccessibilityRequested"
    private let screenRecordingRequestedKey = "NebulaTracker.ScreenRecordingRequested"
    private let lastPromptDateKey = "NebulaTracker.LastPermissionPromptDate"

    var hasRequestedAccessibility: Bool {
        get { defaults.bool(forKey: accessibilityRequestedKey) }
        set {
            defaults.set(newValue, forKey: accessibilityRequestedKey)
            if newValue {
                defaults.set(Date(), forKey: "\(accessibilityRequestedKey).Date")
            }
        }
    }

    var hasRequestedScreenRecording: Bool {
        get { defaults.bool(forKey: screenRecordingRequestedKey) }
        set {
            defaults.set(newValue, forKey: screenRecordingRequestedKey)
            if newValue {
                defaults.set(Date(), forKey: "\(screenRecordingRequestedKey).Date")
            }
        }
    }

    var lastPromptDate: Date? {
        get { defaults.object(forKey: lastPromptDateKey) as? Date }
        set { defaults.set(newValue, forKey: lastPromptDateKey) }
    }

    // Check if enough time has passed since last prompt (e.g., 24 hours)
    func canPromptAgain() -> Bool {
        guard let lastPrompt = lastPromptDate else { return true }
        let hoursSinceLastPrompt = Date().timeIntervalSince(lastPrompt) / 3600
        return hoursSinceLastPrompt > 24 // Only allow re-prompting after 24 hours
    }

    func resetPermissionRequests() {
        hasRequestedAccessibility = false
        hasRequestedScreenRecording = false
        lastPromptDate = nil
    }
}