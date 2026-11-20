#!/usr/bin/env bash
# Build (Debug) and launch the app. Exports .env if present without ever printing its values.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

"$ROOT_DIR/scripts/build.sh"
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Debug/CurrencyNotch.app"

if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env" >/dev/null 2>&1
    set +a
    log "Loaded .env (values not shown)"
fi

pkill -x CurrencyNotch 2>/dev/null || true
log "Launching CurrencyNotch"
# Run the binary directly so the exported environment reaches the app.
"$APP_PATH/Contents/MacOS/CurrencyNotch" >/dev/null 2>&1 &
disown
echo "    pid $!"
