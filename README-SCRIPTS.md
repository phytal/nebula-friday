# Nebula Tracker - Development Guide

Quick reference for the development workflow.

## The One Script: `./dev.sh`

All development tasks in one simple script:

```bash
./dev.sh [command]
```

### Commands

#### `./dev.sh run`
**Most common - quick dev cycle**
- Builds the project
- Deploys to `/Applications`
- Launches with live debug output
- Press Ctrl+C to stop

```bash
./dev.sh run
```

#### `./dev.sh deploy`
**Build and deploy without running**
- Builds the project
- Stops any running instances
- Deploys to `/Applications/NebulaTracker.app`

```bash
./dev.sh deploy
```

#### `./dev.sh build`
**Just build**
- Compiles the Swift project
- No deployment

```bash
./dev.sh build
```

#### `./dev.sh clean`
**Clean build artifacts**
- Removes `.build` directory
- Forces fresh rebuild next time

```bash
./dev.sh clean
```

#### `./dev.sh reset`
**Reset for testing**
- Stops the app
- Clears UserDefaults
- Resets macOS permissions (Accessibility, Screen Recording)
- Useful for testing fresh install flow

```bash
./dev.sh reset
```

---

## Quick Manual Commands

If you prefer doing things manually:

### Build:
```bash
swift build
```

### Deploy:
```bash
cp .build/debug/NebulaTracker "NebulaTracker.app/Contents/MacOS/"
cp -R NebulaTracker.app /Applications/
```

### Run with debug:
```bash
/Applications/NebulaTracker.app/Contents/MacOS/NebulaTracker 2>&1
```

### Kill app:
```bash
pkill -9 NebulaTracker
```

---

## Typical Development Workflow

1. **Make code changes**

2. **Test changes:**
   ```bash
   ./dev.sh run
   ```

3. **Watch debug output**, press Ctrl+C when done

4. **Repeat!**

---

## Testing Fresh Install Experience

When testing permission flows or first-run experience:

```bash
./dev.sh reset    # Clear all settings and permissions
./dev.sh run      # Launch and test fresh install
```

---

## Project Structure

```
nebula-tracker/
├── Sources/              # Swift source code
│   ├── NebulaTrackerApp.swift
│   ├── PermissionChecker.swift
│   ├── Configuration.swift
│   └── ...
├── Resources/            # App resources (icons, etc)
├── NebulaTracker.app/    # App bundle (generated)
├── .build/               # Build artifacts
└── dev.sh                # Development script ⭐
```
