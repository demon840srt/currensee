#!/usr/bin/env bash
# Shared paths for the project scripts. Sourced, not executed.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/backend/CurrencyCore"
APP_DIR="$ROOT_DIR/frontend/CurrencyNotch"
PROJECT="$APP_DIR/CurrencyNotch.xcodeproj"
SCHEME="CurrencyNotch"
BUILD_DIR="$ROOT_DIR/build"
MIN_XCODE_MAJOR=26

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Shells started without the user's profile (some terminals, editors, launchd) lack Homebrew on PATH;
# add its standard locations so xcodegen is found.
for brew_bin in /opt/homebrew/bin /usr/local/bin; do
    if [[ -d "$brew_bin" && ":$PATH:" != *":$brew_bin:"* ]]; then PATH="$brew_bin:$PATH"; fi
done
export PATH

require_xcodegen() {
    command -v xcodegen >/dev/null || die "xcodegen not found. Install it with: brew install xcodegen"
}

# Regenerate the Xcode project every time (about a second) so added or removed files are always picked up.
ensure_project() {
    if [[ ! -d "$PROJECT" ]]; then
        "$ROOT_DIR/scripts/bootstrap.sh"
    else
        require_xcodegen
        (cd "$APP_DIR" && xcodegen generate --quiet)
    fi
}
