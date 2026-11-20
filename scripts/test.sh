#!/usr/bin/env bash
# Run all tests: CurrencyCore (swift test) and the app (xcodebuild test). Exits non-zero on failure.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

log "CurrencyCore: swift test"
(cd "$CORE_DIR" && swift test)

ensure_project
log "CurrenSee app: xcodebuild test"
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -quiet

log "All tests passed"
