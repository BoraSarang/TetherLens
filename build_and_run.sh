#!/bin/bash
# v1.6 디스패처 — 실제 빌드는 scripts/build-{platform}.sh가 담당
set -e

APP_NAME="TetherLens"
BUNDLE_ID="com.tetherlens.app"
DEST_MACOS="$HOME/Applications"
BUILD_DIR="./build"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[build_and_run]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

MODE="debug"
PLATFORM="auto"
DEVICE=""
DO_CLEAN=false

for arg in "$@"; do
  case $arg in
    debug|release) MODE="$arg" ;;
    macos|ios|android|web|all) PLATFORM="$arg" ;;
    clean) DO_CLEAN=true ;;
    --device=*) DEVICE="${arg#*=}" ;;
    -h|--help) echo "Usage: ./build_and_run.sh [debug|release] [macos|ios|android|web|all] [clean] [--device=NAME]"; exit 0 ;;
    *) echo "알 수 없는 인자: $arg"; exit 1 ;;
  esac
done

# 플랫폼 자동 감지 — macOS SwiftPM
if [ "$PLATFORM" = "auto" ]; then
  PLATFORM="macos"
fi

run_platform() {
  local p=$1
  log "▶ $p $MODE 빌드 시작 (device: ${DEVICE:-default})"
  case $p in
    macos) exec ./scripts/build-macos.sh $MODE $DO_CLEAN ;;
    ios|android|web)
      error "$p: 지원하지 않는 플랫폼 (현재 macOS 전용)"
      exit 1 ;;
  esac
}

if [ "$PLATFORM" = "all" ]; then
  for p in macos; do
    if [ -f "./scripts/build-$p.sh" ]; then run_platform $p; fi
  done
else
  run_platform $PLATFORM
fi
