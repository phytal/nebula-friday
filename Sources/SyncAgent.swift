import Foundation
import Cocoa

struct SyncResponse: Codable {
    let success: Bool
    let processedEvents: [Int64]
    let message: String?
}

class SyncAgent {
    static let shared = SyncAgent()
    private var syncTimer: Timer?
    private let config: Configuration
    private var isSyncing = false

    init() {
        config = Configuration.shared
        startPeriodicSync()
    }

    private func startPeriodicSync() {
        // Sync every 60 seconds by default
        let interval = config.syncInterval ?? 60.0
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.syncEvents()
            }
        }

        // Initial sync after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task {
                await self.syncEvents()
            }
        }
    }

    func syncEvents() async {
        guard !isSyncing else {
            print("Sync already in progress, skipping...")
            return
        }

        guard let apiEndpoint = config.apiEndpoint,
              let apiToken = config.apiToken else {
            print("API configuration missing")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Get unsynced events
        let events = EventLogger.shared.getUnsyncedEvents()

        if events.isEmpty {
            print("No events to sync")
            return
        }

        print("Syncing \(events.count) events...")

        // Process in batches
        let batchSize = 10
        for i in stride(from: 0, to: events.count, by: batchSize) {
            let batch = Array(events[i..<min(i + batchSize, events.count)])
            await syncBatch(batch, to: apiEndpoint, token: apiToken)
        }
    }

    private func syncBatch(_ events: [MemoryEvent], to endpoint: String, token: String) async {
        var syncedEventIds: [Int64] = []

        for event in events {
            // Prepare event data
            var eventData: [String: Any] = [
                "type": event.type.rawValue,
                "app_name": event.appName,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
            ]

            if let windowTitle = event.windowTitle {
                eventData["window_title"] = windowTitle
            }

            if let metadata = event.metadata {
                eventData["metadata"] = metadata
            }

            // Handle screenshot upload
            if let screenshotPath = event.screenshotPath {
                if let screenshotData = loadAndCompressScreenshot(path: screenshotPath) {
                    eventData["screenshot"] = screenshotData.base64EncodedString()
                }
            }

            // Send to server
            if await sendEvent(eventData, to: endpoint, token: token) {
                if let eventId = event.id {
                    syncedEventIds.append(eventId)
                }
            }
        }

        // Mark synced events
        if !syncedEventIds.isEmpty {
            EventLogger.shared.markEventsSynced(eventIds: syncedEventIds)
            print("Successfully synced \(syncedEventIds.count) events")
        }
    }

    private func sendEvent(_ eventData: [String: Any], to endpoint: String, token: String) async -> Bool {
        guard let url = URL(string: endpoint) else {
            print("Invalid API endpoint")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return true
                } else {
                    print("Server returned status code: \(httpResponse.statusCode)")

                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                }
            }
        } catch {
            print("Error sending event: \(error)")
        }

        return false
    }

    private func loadAndCompressScreenshot(path: String) -> Data? {
        let fileURL = URL(fileURLWithPath: path)

        do {
            let imageData = try Data(contentsOf: fileURL)

            // If file is already reasonably sized, return as-is
            if imageData.count < 500_000 { // 500KB
                return imageData
            }

            // Otherwise, compress further
            guard let image = NSImage(data: imageData) else { return nil }
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

            // Resize if too large
            let maxDimension: CGFloat = 1920
            var targetSize = CGSize(width: cgImage.width, height: cgImage.height)

            if CGFloat(cgImage.width) > maxDimension || CGFloat(cgImage.height) > maxDimension {
                let scale = maxDimension / max(CGFloat(cgImage.width), CGFloat(cgImage.height))
                targetSize = CGSize(
                    width: CGFloat(cgImage.width) * scale,
                    height: CGFloat(cgImage.height) * scale
                )
            }

            // Create resized image
            let resizedImage = NSImage(size: targetSize)
            resizedImage.lockFocus()
            NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                .draw(in: NSRect(origin: .zero, size: targetSize))
            resizedImage.unlockFocus()

            // Convert to JPEG with compression
            guard let resizedCGImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            let bitmapRep = NSBitmapImageRep(cgImage: resizedCGImage)
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])

        } catch {
            print("Error loading screenshot: \(error)")
            return nil
        }
    }

    func pause() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    func resume() {
        startPeriodicSync()
    }

    deinit {
        syncTimer?.invalidate()
    }
}