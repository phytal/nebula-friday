import Foundation

struct ConfigFile: Codable {
    let apiEndpoint: String?
    let apiToken: String?
    let syncInterval: Double?
    let captureInterval: Double?
    let enableScreenCapture: Bool?
    let enableWindowTracking: Bool?
    let maxScreenshotSize: Int?
    let debugMode: Bool?
}

class Configuration {
    static let shared = Configuration()

    var apiEndpoint: String?
    var apiToken: String?
    var syncInterval: Double?
    var captureInterval: Double?
    var enableScreenCapture: Bool = true
    var enableWindowTracking: Bool = true
    var maxScreenshotSize: Int = 1920
    var debugMode: Bool = false

    private let configPath: URL

    init() {
        // Default config location
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupportDir.appendingPathComponent("NebulaTracker")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        configPath = configDir.appendingPathComponent("config.json")

        // Load configuration
        loadConfig()

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath.path) {
            createDefaultConfig()
        }
    }

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("Config file not found at \(configPath.path)")
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            let config = try JSONDecoder().decode(ConfigFile.self, from: data)

            // Apply configuration
            self.apiEndpoint = config.apiEndpoint
            self.apiToken = config.apiToken
            self.syncInterval = config.syncInterval ?? 60.0
            self.captureInterval = config.captureInterval ?? 30.0
            self.enableScreenCapture = config.enableScreenCapture ?? true
            self.enableWindowTracking = config.enableWindowTracking ?? true
            self.maxScreenshotSize = config.maxScreenshotSize ?? 1920
            self.debugMode = config.debugMode ?? false

            print("Configuration loaded from \(configPath.path)")
        } catch {
            print("Error loading configuration: \(error)")
        }
    }

    private func createDefaultConfig() {
        let defaultConfig = ConfigFile(
            apiEndpoint: "https://api.nebula.app/v1/memory-events",
            apiToken: "YOUR_API_TOKEN_HERE",
            syncInterval: 60.0,
            captureInterval: 30.0,
            enableScreenCapture: true,
            enableWindowTracking: true,
            maxScreenshotSize: 1920,
            debugMode: false
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(defaultConfig)
            try data.write(to: configPath)

            print("Created default config at \(configPath.path)")
            print("Please edit the config file to add your API token")
        } catch {
            print("Error creating default config: \(error)")
        }
    }

    func reload() {
        loadConfig()
    }

    func isConfigured() -> Bool {
        return apiEndpoint != nil && apiToken != nil && apiToken != "YOUR_API_TOKEN_HERE"
    }

    func saveConfig() {
        let config = ConfigFile(
            apiEndpoint: apiEndpoint,
            apiToken: apiToken,
            syncInterval: syncInterval,
            captureInterval: captureInterval,
            enableScreenCapture: enableScreenCapture,
            enableWindowTracking: enableWindowTracking,
            maxScreenshotSize: maxScreenshotSize,
            debugMode: debugMode
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configPath)

            print("Configuration saved successfully")
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}