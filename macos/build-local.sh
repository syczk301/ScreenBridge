#!/bin/bash
# Build an isolated local app without Xcode, Sparkle, or network downloads.
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/sparkle/bootstrap.py
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/映桥.app"
ARCH="$(uname -m)"
mkdir -p "$BUILD/module-cache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
echo "Building 映桥 for ${ARCH}..."
swiftc -O -swift-version 6 -parse-as-library \
  -module-cache-path "$BUILD/module-cache" \
  -target "$ARCH-apple-macos14.0" \
  -import-objc-header Crisp/Crisp-Bridging-Header.h \
  -F tools/sparkle/vendor -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
  -Xlinker -undefined -Xlinker dynamic_lookup \
  Crisp/App/*.swift Crisp/Models/*.swift Crisp/Services/*.swift \
  Crisp/Views/*.swift Crisp/Utilities/*.swift \
  -o "$APP/Contents/MacOS/ScreenBridge"
swiftc -O -swift-version 6 -module-cache-path "$BUILD/module-cache" \
  -target "$ARCH-apple-macos14.0" Sources/crispctl/*.swift \
  Crisp/Models/CrispControlModel.swift Crisp/Models/BrightnessKeySteps.swift \
  -o "$APP/Contents/MacOS/crispctl"
swift -module-cache-path "$BUILD/module-cache" local-tools/generate-icon.swift local-assets/AppIcon
python3 local-tools/bundle.py "$APP"
codesign --force --sign - "$APP/Contents/MacOS/crispctl"
python3 tools/sparkle/bootstrap.py "$APP"
codesign --force --sign - --entitlements Crisp/Crisp.entitlements "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
