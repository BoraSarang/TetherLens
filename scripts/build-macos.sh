#!/bin/bash
# macOS-specific build script — v1.6
set -e

APP_NAME="TetherLens"
DEST_DIR="$HOME/Applications"
BUILD_DIR="./.build"
CODESIGN_IDENTITY="Apple Development: leeborasarang@gmail.com (HLQNBZHQQN)"

MODE=$1
DO_CLEAN=$2

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[build-macos]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log "실행 중인 $APP_NAME 종료..."
pkill -9 "$APP_NAME" 2>/dev/null || true
killall "$APP_NAME" 2>/dev/null || true
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1

if [ "$DO_CLEAN" = true ]; then
  log "clean 수행"
  rm -rf "$BUILD_DIR" ./dist ./out
  rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
fi

mkdir -p "$DEST_DIR"

CONFIG_FLAG=""
[ "$MODE" = "release" ] && CONFIG_FLAG="-c release"

log "빌드 시작 (mode: $MODE)"
swift build $CONFIG_FLAG

BUILD_MODE_DIR="debug"
[ "$MODE" = "release" ] && BUILD_MODE_DIR="release"
BINARY="$BUILD_DIR/$BUILD_MODE_DIR/$APP_NAME"
APP_BUNDLE="$DEST_DIR/$APP_NAME.app"

log "앱 번들 생성..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "Resources/TetherLens.icns" "$APP_BUNDLE/Contents/Resources/"

if [ "$MODE" = "release" ]; then
    log "릴리스 최적화..."
    strip "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

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
/usr/bin/codesign --force --deep --sign "$CODESIGN_IDENTITY" --entitlements /tmp/tetherlens_entitlements.plist "$APP_BUNDLE" 2>/dev/null || \
    warn "코드 서명 실패 (로컬 개발에서는 무시 가능)"

log "실행: $APP_BUNDLE"
open "$APP_BUNDLE"
log "실행 완료 ($MODE) - DebugPanel: $([ "$MODE" = "debug" ] && echo "ON" || echo "OFF")"
