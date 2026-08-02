#!/bin/bash
# Package TetherLens as a .app bundle

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/debug"
APP_NAME="TetherLens"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"

echo "Building..."
cd "$PROJECT_DIR"
swift build

echo "Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Set rpath so Sparkle can be found at Contents/Frameworks/
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "$PROJECT_DIR/Resources/TetherLens.icns" "$APP_BUNDLE/Contents/Resources/"

# Sign the app bundle (deep sign includes frameworks)
CODESIGN_IDENTITY="Apple Development: leeborasarang@gmail.com (HLQNBZHQQN)"
cat > /tmp/tetherlens_entitlements.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.personal-information.location</key>
    <true/>
</dict>
</plist>
EOF
/usr/bin/codesign --force --deep --sign "$CODESIGN_IDENTITY" --entitlements /tmp/tetherlens_entitlements.plist "$APP_BUNDLE"

echo "App bundle created at $APP_BUNDLE"

# Kill existing process and launch new version
if pkill -x "$APP_NAME" 2>/dev/null; then
    echo "Killed existing $APP_NAME process"
    sleep 0.5
fi
open "$APP_BUNDLE"
echo "Launched $APP_NAME"
