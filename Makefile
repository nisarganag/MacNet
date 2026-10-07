APP_NAME := MacNet
# Releases are git tags (vX.Y.Z) and the app's version is read from them, so a
# release never needs a version-bump commit. Untagged builds report the most
# recent release (0.0.0 before the first); Scripts/release.sh passes the new
# version explicitly with `make VERSION=x.y.z ...`.
LAST_TAG := $(shell git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null)
VERSION  ?= $(if $(LAST_TAG),$(LAST_TAG:v%=%),0.0.0)
# Monotonic build number: one per commit, so every release gets a higher one.
BUILD    := $(shell git rev-list --count HEAD 2>/dev/null || echo 0)

# The macOS 27 SDK implements SwiftUI's @State as a macro whose compiler
# plugin ships only with full Xcode, so under Command Line Tools every @State
# fails to expand. The 26.5 SDK still has it as a property wrapper and already
# carries every Liquid Glass API the app uses. Override with
# `make SDKROOT=...` when building under full Xcode.
SDKROOT ?= $(shell xcrun --sdk macosx26.5 --show-sdk-path 2>/dev/null)
export SDKROOT

DIST     := dist
APP      := $(DIST)/$(APP_NAME).app
DMG      := $(DIST)/$(APP_NAME)-$(VERSION).dmg
ZIP      := $(DIST)/$(APP_NAME)-$(VERSION).zip
STAGING  := $(DIST)/dmg-staging
# One invocation with both --arch flags yields a universal binary under
# Swift 6.4's native build system; --show-bin-path says where it landed.
ARCHS    := --arch arm64 --arch x86_64
INSTALLED := /Applications/$(APP_NAME).app

# Swift Build (6.4, Command Line Tools) intermittently re-plans test compiles
# without the swift-testing macro plugin, and every @Test / #expect then fails
# with "plugin for module 'TestingMacros' not found" (reproduced by changing
# any environment variable between runs). Pointing the compiler at the active
# toolchain's plugin directory makes the macros resolvable either way.
TESTING_PLUGINS := $(abspath $(dir $(shell xcrun --find swift))../lib/swift/host/plugins/testing)
TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: all test build bundle icon dmg zip install run release clean

all: bundle

test:
	swift test $(TEST_FLAGS)
	bash Tests/scripts/release-version-test.sh
	bash Tests/scripts/release-push-test.sh

build:
	swift build -c release $(ARCHS)

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy \
		-c "Set :CFBundleShortVersionString $(VERSION)" \
		-c "Set :CFBundleVersion $(BUILD)" \
		$(APP)/Contents/Info.plist
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/$(APP_NAME)" $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)
	@echo "built $(APP) $(VERSION) ($(BUILD))"

# Regenerates Resources/AppIcon.icns (and the 1024 px preview) from code.
icon:
	swift Scripts/make-icon.swift

dmg: bundle
	rm -rf $(STAGING) $(DMG)
	mkdir -p $(STAGING)
	ditto $(APP) $(STAGING)/$(APP_NAME).app
	ln -s /Applications $(STAGING)/Applications
	hdiutil create -volname "$(APP_NAME) $(VERSION)" -srcfolder $(STAGING) -ov -format UDZO $(DMG)
	rm -rf $(STAGING)
	@echo "built $(DMG)"

zip: bundle
	rm -f $(ZIP)
	ditto -c -k --sequesterRsrc --keepParent $(APP) $(ZIP)
	@echo "built $(ZIP)"

# SIGTERM is handled in-app as a normal quit, so a running speed test is
# cleaned up before the bundle is replaced underneath it.
install: bundle
	-pkill -x $(APP_NAME)
	@for i in $$(seq 1 50); do pgrep -x $(APP_NAME) >/dev/null || break; sleep 0.1; done
	rm -rf $(INSTALLED)
	ditto $(APP) $(INSTALLED)
	open $(INSTALLED)
	@echo "installed $(INSTALLED) $(VERSION) ($(BUILD))"

run: bundle
	$(APP)/Contents/MacOS/$(APP_NAME)

# Tags, builds, installs and publishes the next version; see Scripts/release.sh.
BUMP ?= patch
release:
	Scripts/release.sh $(BUMP)

clean:
	rm -rf .build $(DIST)
