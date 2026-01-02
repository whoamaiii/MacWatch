# Clarity - macOS Usage Analytics App
# Build, Sign, and Distribute Makefile

# Configuration
APP_NAME = Clarity
BUNDLE_ID = com.clarity.app
DAEMON_BUNDLE_ID = com.clarity.daemon
VERSION = 1.0.0

# Paths
BUILD_DIR = .build/release
DIST_DIR = dist
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app
DAEMON_BUNDLE = $(APP_BUNDLE)/Contents/MacOS/ClarityDaemon
DMG_NAME = $(APP_NAME)-$(VERSION).dmg

# Source paths
APP_ENTITLEMENTS = Sources/ClarityApp/ClarityApp.entitlements
DAEMON_ENTITLEMENTS = Sources/ClarityDaemon/ClarityDaemon.entitlements
APP_INFO_PLIST = Sources/ClarityApp/Info.plist
DAEMON_INFO_PLIST = Sources/ClarityDaemon/Info.plist

# Signing identity (set via environment variable)
# export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
DEVELOPER_ID ?= -

# Notarization credentials (set via environment variables)
# export APPLE_ID="your@email.com"
# export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password
# export TEAM_ID="XXXXXXXXXX"
APPLE_ID ?=
APP_PASSWORD ?=
TEAM_ID ?=

.PHONY: all clean build release bundle sign notarize dmg install uninstall test help

# Default target
all: release

# Show help
help:
	@echo "Clarity Build System"
	@echo "===================="
	@echo ""
	@echo "Build targets:"
	@echo "  make build      - Debug build"
	@echo "  make release    - Release build"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Clean build artifacts"
	@echo ""
	@echo "Distribution targets:"
	@echo "  make bundle     - Create .app bundle"
	@echo "  make sign       - Sign with Developer ID"
	@echo "  make notarize   - Notarize with Apple"
	@echo "  make dmg        - Create distributable DMG"
	@echo ""
	@echo "Install targets:"
	@echo "  make install    - Install to /Applications"
	@echo "  make uninstall  - Remove from /Applications"
	@echo ""
	@echo "Environment variables for signing:"
	@echo "  DEVELOPER_ID    - Your Developer ID certificate name"
	@echo ""
	@echo "Environment variables for notarization:"
	@echo "  APPLE_ID        - Your Apple ID email"
	@echo "  APP_PASSWORD    - App-specific password"
	@echo "  TEAM_ID         - Your Apple Developer Team ID"

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(DIST_DIR)
	rm -rf .build

# Debug build
build:
	swift build

# Release build
release:
	swift build -c release

# Run tests
test:
	swift test

# Create app bundle structure
bundle: release
	@echo "Creating app bundle..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources

	# Copy executables
	@cp $(BUILD_DIR)/ClarityApp $(APP_BUNDLE)/Contents/MacOS/
	@cp $(BUILD_DIR)/ClarityDaemon $(APP_BUNDLE)/Contents/MacOS/

	# Copy Info.plist
	@cp $(APP_INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist

	# Create PkgInfo
	@echo "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo

	# Copy icon if exists
	@if [ -f "Resources/AppIcon.icns" ]; then \
		cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; \
	fi

	# Remove extended attributes that break codesigning
	@xattr -cr $(APP_BUNDLE)

	@echo "Bundle created at $(APP_BUNDLE)"

# Sign the app bundle
sign: bundle
	@echo "Signing app bundle..."
	@if [ "$(DEVELOPER_ID)" = "-" ]; then \
		echo "Warning: No DEVELOPER_ID set, using ad-hoc signing"; \
		codesign --force --deep --sign - \
			--entitlements $(APP_ENTITLEMENTS) \
			--options runtime \
			$(APP_BUNDLE); \
	else \
		echo "Signing with: $(DEVELOPER_ID)"; \
		codesign --force --deep --sign "$(DEVELOPER_ID)" \
			--entitlements $(APP_ENTITLEMENTS) \
			--options runtime \
			--timestamp \
			$(APP_BUNDLE); \
	fi

	# Sign the daemon separately with its entitlements
	@if [ "$(DEVELOPER_ID)" != "-" ]; then \
		codesign --force --sign "$(DEVELOPER_ID)" \
			--entitlements $(DAEMON_ENTITLEMENTS) \
			--options runtime \
			--timestamp \
			$(APP_BUNDLE)/Contents/MacOS/ClarityDaemon; \
	fi

	# Verify signature
	@codesign --verify --verbose $(APP_BUNDLE)
	@echo "Signing complete"

# Notarize the app
notarize: sign
	@echo "Notarizing app..."
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(APP_PASSWORD)" ] || [ -z "$(TEAM_ID)" ]; then \
		echo "Error: APPLE_ID, APP_PASSWORD, and TEAM_ID must be set"; \
		exit 1; \
	fi

	# Create zip for notarization
	@ditto -c -k --keepParent $(APP_BUNDLE) $(DIST_DIR)/$(APP_NAME).zip

	# Submit for notarization
	@xcrun notarytool submit $(DIST_DIR)/$(APP_NAME).zip \
		--apple-id "$(APPLE_ID)" \
		--password "$(APP_PASSWORD)" \
		--team-id "$(TEAM_ID)" \
		--wait

	# Staple the ticket
	@xcrun stapler staple $(APP_BUNDLE)

	# Clean up zip
	@rm $(DIST_DIR)/$(APP_NAME).zip

	@echo "Notarization complete"

# Create DMG for distribution
dmg: sign
	@echo "Creating DMG..."
	@mkdir -p $(DIST_DIR)/dmg-staging
	@cp -R $(APP_BUNDLE) $(DIST_DIR)/dmg-staging/
	@ln -s /Applications $(DIST_DIR)/dmg-staging/Applications

	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(DIST_DIR)/dmg-staging \
		-ov -format UDZO \
		$(DIST_DIR)/$(DMG_NAME)

	@rm -rf $(DIST_DIR)/dmg-staging

	# Sign DMG if we have a developer ID
	@if [ "$(DEVELOPER_ID)" != "-" ]; then \
		codesign --sign "$(DEVELOPER_ID)" --timestamp $(DIST_DIR)/$(DMG_NAME); \
	fi

	@echo "DMG created at $(DIST_DIR)/$(DMG_NAME)"

# Install to Applications folder
install: bundle
	@echo "Installing to /Applications..."
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed $(APP_NAME).app to /Applications"

# Uninstall from Applications folder
uninstall:
	@echo "Removing from /Applications..."
	@rm -rf /Applications/$(APP_NAME).app
	@echo "Uninstalled $(APP_NAME).app"

# Full distribution build (for release)
dist: clean notarize dmg
	@echo ""
	@echo "Distribution build complete!"
	@echo "DMG: $(DIST_DIR)/$(DMG_NAME)"
