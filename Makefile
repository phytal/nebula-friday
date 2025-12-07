# Makefile for NebulaTracker

SWIFT = swiftc
SOURCES = Sources/*.swift
TARGET = NebulaTracker
INSTALL_PATH = /usr/local/bin/nebula-tracker

# Build flags
FLAGS = -O -whole-module-optimization
FRAMEWORKS = -framework Cocoa -framework CoreGraphics -framework ApplicationServices

.PHONY: all build install clean

all: build

build:
	@echo "Building NebulaTracker..."
	@$(SWIFT) $(FLAGS) $(FRAMEWORKS) $(SOURCES) -o $(TARGET)
	@echo "Build complete!"

install: build
	@echo "Installing to $(INSTALL_PATH)..."
	@sudo cp $(TARGET) $(INSTALL_PATH)
	@sudo chmod +x $(INSTALL_PATH)
	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit configuration: ~/Library/Application Support/NebulaTracker/config.json"
	@echo "2. Grant permissions: nebula-tracker --permissions"
	@echo "3. Load the agent: launchctl load ~/Library/LaunchAgents/com.nebula.tracker.plist"

clean:
	@rm -f $(TARGET)
	@echo "Cleaned build artifacts"

run: build
	@./$(TARGET)