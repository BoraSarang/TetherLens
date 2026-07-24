#!/bin/bash
# Package TetherLens as a .app bundle

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/debug"
APP_NAME="TetherLens"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Building..."
cd "$PROJECT_DIR"
swift build

echo "Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

echo "App bundle created at $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
