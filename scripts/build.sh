#!/usr/bin/env bash
# Debug build of the app into ./build. Prints the path to the built .app.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

ensure_project
log "Building CurrencyNotch (Debug)"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -quiet

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Debug/CurrencyNotch.app"
[[ -d "$APP_PATH" ]] || die "Build finished but $APP_PATH is missing."
echo "    $APP_PATH"
