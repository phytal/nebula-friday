#!/bin/bash
# Nebula Tracker - Development Script
# One script to rule them all!

set -e

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    echo "Nebula Tracker Development Script"
    echo ""
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build    - Build the project"
    echo "  deploy   - Build and deploy to /Applications"
    echo "  run      - Build, deploy, and run with debug output"
    echo "  clean    - Clean build artifacts"
    echo "  reset    - Reset permissions and UserDefaults (for testing)"
    echo ""
    echo "Examples:"
    echo "  ./dev.sh run     # Quick dev cycle"
    echo "  ./dev.sh deploy  # Just deploy without running"
}

build() {
    echo -e "${BLUE}🔨 Building...${NC}"
    swift build 2>&1 | tail -5
}

deploy() {
    build

    echo ""
    echo -e "${YELLOW}🛑 Stopping running instances...${NC}"
    pkill -9 NebulaTracker 2>/dev/null || true
    sleep 1

    echo ""
    echo -e "${BLUE}📦 Deploying to /Applications...${NC}"
    cp .build/debug/NebulaTracker "NebulaTracker.app/Contents/MacOS/"
    cp -R NebulaTracker.app /Applications/

    echo ""
    echo -e "${GREEN}✅ Deployed successfully!${NC}"
}

run() {
    deploy

    echo ""
    echo -e "${GREEN}🚀 Launching with debug output...${NC}"
    echo -e "${YELLOW}   (Press Ctrl+C to stop)${NC}"
    echo ""
    /Applications/NebulaTracker.app/Contents/MacOS/NebulaTracker 2>&1
}

clean() {
    echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"
    rm -rf .build
    echo -e "${GREEN}✅ Clean complete!${NC}"
}

reset() {
    echo -e "${YELLOW}⚠️  Resetting permissions and settings...${NC}"

    # Kill app first
    pkill -9 NebulaTracker 2>/dev/null || true
    sleep 1

    # Reset UserDefaults
    defaults delete com.nebula.tracker 2>/dev/null || true
    defaults delete com.nebula.tracker.NebulaTracker 2>/dev/null || true

    # Reset TCC permissions
    tccutil reset Accessibility com.nebula.tracker 2>/dev/null || true
    tccutil reset ScreenCapture com.nebula.tracker 2>/dev/null || true

    echo -e "${GREEN}✅ Reset complete! Relaunch app to test fresh install flow.${NC}"
}

# Parse command
case "${1:-}" in
    build)
        build
        ;;
    deploy)
        deploy
        ;;
    run)
        run
        ;;
    clean)
        clean
        ;;
    reset)
        reset
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
