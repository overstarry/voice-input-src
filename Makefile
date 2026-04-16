APP_NAME := VoiceInput
PRODUCT := .build/release/$(APP_NAME)
APP_BUNDLE := .build/release/$(APP_NAME).app
CONTENTS := $(APP_BUNDLE)/Contents
MACOS := $(CONTENTS)/MacOS
SIGN_IDENTITY ?= -
INSTALL_DIR ?= /Applications

.PHONY: build run install clean

build:
	swift build -c release
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(MACOS)"
	cp "$(PRODUCT)" "$(MACOS)/$(APP_NAME)"
	cp "Resources/Info.plist" "$(CONTENTS)/Info.plist"
	codesign --force --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

install: build
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf .build
