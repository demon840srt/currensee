#!/usr/bin/env bash
# Personal-use release (ADR-0023): run tests, build Release, verify the signature and sandbox, install to
# /Applications. No Developer ID, notarization or secrets.
#
# Usage: ./scripts/release.sh [--dmg] [--yes] [--open] [--skip-tests]
#   --dmg         also write a backup DMG to dist/
#   --yes         replace an existing /Applications copy without asking (needed when not run in a terminal)
#   --open        launch the installed app afterwards
#   --skip-tests  skip ./scripts/test.sh (not recommended)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

MAKE_DMG=0; ASSUME_YES=0; OPEN_AFTER=0; RUN_TESTS=1
for arg in "$@"; do
    case "$arg" in
        --dmg) MAKE_DMG=1 ;;
        --yes) ASSUME_YES=1 ;;
        --open) OPEN_AFTER=1 ;;
        --skip-tests) RUN_TESTS=0 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) die "Unknown option: $arg (see --help)" ;;
    esac
done

APP_NAME="CurrencyNotch.app"
INSTALL_PATH="/Applications/$APP_NAME"
RELEASE_APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"

if (( RUN_TESTS )); then
    "$ROOT_DIR/scripts/test.sh"
fi

ensure_project
log "Building CurrencyNotch (Release)"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -quiet
[[ -d "$RELEASE_APP" ]] || die "Build finished but $RELEASE_APP is missing."

log "Verifying the build"
codesign --verify --deep --strict "$RELEASE_APP" || die "Code signature is invalid."
flags="$(codesign -dv "$RELEASE_APP" 2>&1 | grep -o 'flags=[^ ]*' || true)"
[[ "$flags" == *runtime* ]] || die "Hardened Runtime is not enabled ($flags)."
entitlements_file="$(mktemp)"
codesign -d --entitlements - --xml "$RELEASE_APP" > "$entitlements_file" 2>/dev/null
entitlement_count="$(plutil -p "$entitlements_file" | grep -c '=>' || true)"
# PlistBuddy (":" separator) — plutil key paths would split the dotted entitlement names.
entitlement() { /usr/libexec/PlistBuddy -c "Print :$1" "$entitlements_file" 2>/dev/null || true; }
[[ "$(entitlement com.apple.security.app-sandbox)" == "true" &&
   "$(entitlement com.apple.security.network.client)" == "true" &&
   "$entitlement_count" == "2" ]] ||
    die "Unexpected entitlements (want exactly sandbox + network client): $(plutil -p "$entitlements_file" | tr -s ' \n' ' ')"
rm -f "$entitlements_file"
if plutil -p "$RELEASE_APP/Contents/Info.plist" | grep -q NSAppTransportSecurity; then
    die "Info.plist contains App Transport Security exceptions."
fi
for debug_switch in CURRENCY_NOTCH_THEME CURRENCY_NOTCH_IGNORE_BATTERY CURRENCY_NOTCH_EFFECTS; do
    if strings -a "$RELEASE_APP/Contents/MacOS/CurrencyNotch" | grep -q "$debug_switch"; then
        die "Debug-only switch $debug_switch found in the Release binary."
    fi
done
version="$(plutil -extract CFBundleShortVersionString raw "$RELEASE_APP/Contents/Info.plist")"
echo "    signature valid, $flags, sandbox + network client only, no ATS exceptions, no Debug switches"

if [[ -d "$INSTALL_PATH" ]]; then
    if (( ! ASSUME_YES )); then
        if [[ -t 0 ]]; then
            read -r -p "Replace the existing $INSTALL_PATH? [y/N] " answer
            [[ "$answer" =~ ^[Yy]$ ]] || die "Not replaced. Nothing installed."
        else
            die "$INSTALL_PATH already exists. Re-run with --yes to replace it."
        fi
    fi
    log "Quitting the running app (if any)"
    osascript -e 'tell application id "com.afik.CurrencyNotch" to quit' >/dev/null 2>&1 || true
    sleep 1
    pkill -x CurrencyNotch 2>/dev/null || true
    rm -rf "$INSTALL_PATH"
fi

log "Installing to $INSTALL_PATH"
ditto "$RELEASE_APP" "$INSTALL_PATH"
codesign --verify --deep --strict "$INSTALL_PATH" || die "Installed copy failed verification."
echo "    Currency Notch $version installed"

if (( MAKE_DMG )); then
    log "Creating backup DMG"
    mkdir -p "$ROOT_DIR/dist"
    staging="$(mktemp -d)"
    trap 'rm -rf "$staging"' EXIT
    ditto "$RELEASE_APP" "$staging/$APP_NAME"
    ln -s /Applications "$staging/Applications"
    dmg="$ROOT_DIR/dist/CurrencyNotch-$version.dmg"
    hdiutil create -volname "Currency Notch" -srcfolder "$staging" -ov -format UDZO "$dmg" -quiet
    echo "    $dmg"
fi

if (( OPEN_AFTER )); then
    log "Launching"
    open "$INSTALL_PATH"
else
    echo "Launch it with: open \"$INSTALL_PATH\""
fi
echo "Reminder: launch at login is a setting in the app (Settings → General)."
