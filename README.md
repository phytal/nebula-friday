# Nebula Tracker

A macOS background agent that monitors user activity through screenshots and window tracking to build a searchable memory of your digital activity.

## Features

- 🖥️ **Window Tracking** - Detects active application and window title changes
- 📸 **Smart Screenshots** - Captures screen only when content changes significantly
- 💾 **Local Storage** - SQLite database for event storage with automatic cleanup
- 🔄 **Background Sync** - Uploads events to Nebula API server
- 🔒 **Privacy-First** - Requires explicit permissions, configurable tracking
- 🎯 **Lightweight** - Minimal CPU/memory usage with intelligent throttling

## Architecture

```
[macOS System Events] → [Nebula Tracker Agent]
                              ↓
                    [Local SQLite Database]
                              ↓
                      [Background Sync]
                              ↓
                      [Nebula API Server]
                              ↓
                    [Vision Model Processing]
```

## Installation

### Prerequisites

- macOS 11.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools

### Build from Source

```bash
# Clone the repository
cd nebula-tracker

# Build the project
./build.sh

# Or manually:
swift build -c release
sudo cp .build/release/NebulaTracker /usr/local/bin/nebula-tracker
```

## Configuration

Edit the configuration file at `~/Library/Application Support/NebulaTracker/config.json`:

```json
{
  "apiEndpoint": "https://api.nebula.app/v1/memory-events",
  "apiToken": "YOUR_API_TOKEN_HERE",
  "syncInterval": 60.0,
  "captureInterval": 30.0,
  "enableScreenCapture": true,
  "enableWindowTracking": true,
  "maxScreenshotSize": 1920,
  "debugMode": false
}
```

### Configuration Options

- **apiEndpoint**: Your Nebula API server endpoint
- **apiToken**: Authentication token for API access
- **syncInterval**: How often to sync events (seconds)
- **captureInterval**: How often to check for screen changes (seconds)
- **enableScreenCapture**: Enable/disable screenshot capture
- **enableWindowTracking**: Enable/disable window change tracking
- **maxScreenshotSize**: Maximum screenshot dimension (pixels)
- **debugMode**: Enable verbose logging

## Permissions Setup

Nebula Tracker requires two system permissions:

### 1. Accessibility Permission

Allows tracking of active windows and applications.

1. Open **System Preferences → Security & Privacy → Privacy → Accessibility**
2. Click the lock to make changes
3. Add `/usr/local/bin/nebula-tracker` to the list
4. Check the checkbox to enable

### 2. Screen Recording Permission

Allows capturing screenshots.

1. Open **System Preferences → Security & Privacy → Privacy → Screen Recording**
2. Click the lock to make changes
3. Add `/usr/local/bin/nebula-tracker` to the list
4. Check the checkbox to enable

## Usage

### Start the Tracker

```bash
# Start manually
nebula-tracker

# Or use LaunchAgent (auto-start on login)
launchctl load ~/Library/LaunchAgents/com.nebula.tracker.plist
```

### Stop the Tracker

```bash
# Stop LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.nebula.tracker.plist

# Or kill the process
pkill nebula-tracker
```

### Command Line Options

```bash
nebula-tracker --help        # Show help
nebula-tracker --version     # Show version
nebula-tracker --status      # Show current status and stats
nebula-tracker --permissions # Show permission setup instructions
```

## API Integration

The tracker sends events to your Nebula API server:

### Event Format

```json
{
  "type": "window_change",
  "app_name": "Safari",
  "window_title": "GitHub - nebula-app",
  "timestamp": "2024-01-15T10:30:45Z",
  "screenshot": "base64_encoded_jpeg_data",
  "metadata": {
    "screen_width": 2560,
    "screen_height": 1440
  }
}
```

### API Endpoint

```
POST /v1/memory-events
Authorization: Bearer YOUR_API_TOKEN
Content-Type: application/json
```

## Privacy & Security

- **Explicit Opt-in**: Requires manual permission grants
- **Local First**: All data stored locally before sync
- **Configurable**: Disable any tracking features
- **Auto Cleanup**: Old events and screenshots deleted automatically
- **No Keylogging**: Only captures visual information, not keystrokes

## Development

### Project Structure

```
nebula-tracker/
├── Sources/
│   ├── NebulaTracker.swift      # Main entry point
│   ├── WindowTracker.swift      # Window/app detection
│   ├── ScreenCapture.swift      # Screenshot capture
│   ├── EventLogger.swift        # SQLite storage
│   ├── SyncAgent.swift          # API sync
│   └── Configuration.swift      # Config management
├── LaunchAgents/
│   └── com.nebula.tracker.plist # LaunchAgent config
├── Package.swift                 # Swift package manifest
└── build.sh                      # Build script
```

### Building for Development

```bash
# Debug build
swift build

# Run tests
swift test

# Generate Xcode project
swift package generate-xcodeproj
```

## Troubleshooting

### Tracker Not Starting

1. Check permissions: `nebula-tracker --permissions`
2. Verify config: `cat ~/Library/Application Support/NebulaTracker/config.json`
3. Check logs: `tail -f /tmp/nebula-tracker.log`

### No Screenshots Being Captured

1. Verify Screen Recording permission is granted
2. Check `enableScreenCapture` is `true` in config
3. Look for errors in `/tmp/nebula-tracker.error.log`

### Events Not Syncing

1. Verify API token is configured
2. Check network connectivity
3. Verify API endpoint is correct
4. Check sync status: `nebula-tracker --status`

### High CPU Usage

1. Increase `captureInterval` in config
2. Reduce `maxScreenshotSize`
3. Disable features you don't need

## License

MIT License - See LICENSE file for details

## Support

For issues or questions, please open an issue on GitHub or contact support@nebula.app
