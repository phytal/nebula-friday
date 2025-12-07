import CoreGraphics
import Cocoa
import CryptoKit
import Foundation

class ScreenCapture {
    static let shared = ScreenCapture()
    private var lastScreenshotHash: String?
    private let screenshotDirectory: URL
    private let compressionQuality: CGFloat = 0.7
    private var captureTimer: Timer?

    init() {
        // Create screenshots directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        screenshotDirectory = appSupportDir.appendingPathComponent("NebulaTracker/Screenshots")

        try? FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)

        // Start periodic capture timer (every 30 seconds to check for changes)
        captureTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.captureIfChanged()
        }
    }

    func captureIfChanged() {
        guard hasScreenRecordingPermission() else {
            print("Screen recording permission not granted")
            return
        }

        guard let image = captureScreen() else {
            print("Failed to capture screen")
            return
        }

        // Calculate hash of the image
        let currentHash = hashImage(image)

        // Check if content changed significantly
        if shouldCapture(currentHash: currentHash) {
            lastScreenshotHash = currentHash

            // Save screenshot
            if let path = saveScreenshot(image) {
                print("Screenshot saved at \(path)")

                // Log the event
                EventLogger.shared.logEvent(
                    type: .screenshot,
                    appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
                    windowTitle: nil,
                    screenshotPath: path
                )
            }
        }
    }

    private func captureScreen() -> CGImage? {
        // Capture main display
        let displayID = CGMainDisplayID()
        return CGDisplayCreateImage(displayID)
    }

    private func hashImage(_ image: CGImage) -> String {
        // Create a smaller version for hashing (faster comparison)
        let smallSize = CGSize(width: 200, height: 150)
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        // Resize for hashing
        let smallImage = NSImage(size: smallSize)
        smallImage.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: smallSize))
        smallImage.unlockFocus()

        // Get data and hash
        guard let tiffData = smallImage.tiffRepresentation else { return "" }
        let hash = SHA256.hash(data: tiffData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func shouldCapture(currentHash: String) -> Bool {
        // Capture if hash changed or first capture
        return currentHash != lastScreenshotHash
    }

    private func saveScreenshot(_ image: CGImage) -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "screenshot_\(timestamp).jpg"
        let fileURL = screenshotDirectory.appendingPathComponent(filename)

        // Convert to JPEG for better compression
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
            return nil
        }

        do {
            try jpegData.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Error saving screenshot: \(error)")
            return nil
        }
    }

    private func hasScreenRecordingPermission() -> Bool {
        // Check if we have screen recording permission
        // This will return false if permission not granted
        if #available(macOS 11.0, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            // For older macOS versions, try to capture and see if it works
            return CGDisplayCreateImage(CGMainDisplayID()) != nil
        }
    }

    func cleanupOldScreenshots(olderThanDays: Int = 7) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -olderThanDays, to: Date())!

        do {
            let files = try FileManager.default.contentsOfDirectory(at: screenshotDirectory, includingPropertiesForKeys: [.creationDateKey])

            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Error cleaning up old screenshots: \(error)")
        }
    }

    deinit {
        captureTimer?.invalidate()
    }
}